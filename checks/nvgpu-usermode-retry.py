# SPDX-License-Identifier: GPL-2.0-only
"""Compile the pinned retry function verbatim; never execute GPU operations.

Only the per-mapping operation, locking, logging and delay are mocked. The
retry loop and nvgpu list implementation come directly from the source input.
The unlock mock deterministically schedules final-entry removal between passes.
"""

import argparse
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


MOCKS = r"""
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <nvgpu/list.h>

struct mock_mutex { bool held; };
struct nvgpu_os_linux {
    struct mock_mutex ctrl_privs_lock;
    struct nvgpu_list_node ctrl_privs;
};
struct gk20a { struct nvgpu_os_linux os; };
struct gk20a_ctrl_priv { struct nvgpu_list_node list; };
static struct gk20a gpu;
static struct gk20a_ctrl_priv entry;
static unsigned int passes, attempts;
static bool remove_final, expected_poweroff;

static struct gk20a_ctrl_priv *gk20a_ctrl_priv_from_list(struct nvgpu_list_node *n)
{
    return (struct gk20a_ctrl_priv *)((uintptr_t)n -
           offsetof(struct gk20a_ctrl_priv, list));
}
static struct nvgpu_os_linux *nvgpu_os_linux_from_gk20a(struct gk20a *g)
{
    return &g->os;
}
static void nvgpu_mutex_acquire(struct mock_mutex *lock)
{
    assert(!lock->held);
    lock->held = true;
    passes++;
}
static void nvgpu_mutex_release(struct mock_mutex *lock)
{
    assert(lock->held);
    lock->held = false;
    if (remove_final && passes == 1) {
        assert(attempts == 1);
        nvgpu_list_del(&entry.list);
        assert(nvgpu_list_empty(&gpu.os.ctrl_privs));
        puts("contention then final control entry removed");
        fflush(stdout);
    }
}
static int alter_usermode_mapping(struct gk20a *g,
                                struct gk20a_ctrl_priv *priv, bool poweroff)
{
    assert(g == &gpu && priv == &entry);
    assert(g->os.ctrl_privs_lock.held);
    assert(poweroff == expected_poweroff);
    return ++attempts == 1 ? -EBUSY : 0;
}
#define nvgpu_log_info(...) ((void)0)
#define nvgpu_err(...) assert(!"unexpected mapping error")
static void nvgpu_udelay(unsigned int delay)
{
    /* Yield in the host fixture; the production delay is not under test. */
    assert(delay == 10);
    usleep(delay);
}
"""

MAIN = r"""
int main(int argc, char **argv)
{
    assert(argc == 3);
    remove_final = strcmp(argv[1], "remove-final") == 0;
    bool empty = strcmp(argv[1], "empty") == 0;
    assert(remove_final || empty || strcmp(argv[1], "retry-success") == 0);
    expected_poweroff = strcmp(argv[2], "poweroff") == 0;
    nvgpu_init_list_node(&gpu.os.ctrl_privs);
    nvgpu_init_list_node(&entry.list);
    if (!empty)
        nvgpu_list_add(&entry.list, &gpu.os.ctrl_privs);
    alter_usermode_mappings(&gpu, expected_poweroff);
    assert(!gpu.os.ctrl_privs_lock.held);
    assert(passes == (empty ? 1U : 2U));
    assert(attempts == (empty ? 0U : remove_final ? 1U : 2U));
    puts("completed with expected passes and mapping attempts");
    return 0;
}
"""


def extract_function(source):
    start = source.index("static void alter_usermode_mappings(")
    end = source.index("\n}\n", start) + len("\n}\n")
    return source[start:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="pinned OOT superproject root")
    parser.add_argument("patch", type=Path)
    args = parser.parse_args()
    relative = Path("nvgpu/drivers/gpu/nvgpu/os/linux/ioctl_ctrl.c")
    original = (args.source / relative).read_text()
    include = args.source / "nvgpu/drivers/gpu/nvgpu/include"
    print("source SHA256:", hashlib.sha256(original.encode()).hexdigest(), flush=True)
    with tempfile.TemporaryDirectory(prefix="nvgpu-usermode-retry-") as temporary:
        root = Path(temporary)
        target = root / relative
        target.parent.mkdir(parents=True)
        target.write_text(original)
        subprocess.run(
            ["patch", "--batch", "--fuzz=0", "-p1", "-i", str(args.patch.resolve())],
            cwd=root,
            check=True,
        )
        # Supply only the standard types needed by the actual upstream list.h.
        types = root / "include/nvgpu/types.h"
        types.parent.mkdir(parents=True)
        types.write_text("#include <stdbool.h>\n#include <stddef.h>\n#include <stdint.h>\n")
        for version, source in [("old", original), ("patched", target.read_text())]:
            function = extract_function(source)
            print(version, "function SHA256:", hashlib.sha256(function.encode()).hexdigest(), flush=True)
            fixture = root / f"{version}.c"
            fixture.write_text(MOCKS + "\n" + function + MAIN)
            executable = root / version
            subprocess.run(
                shlex.split(os.environ.get("CC", "cc"))
                + ["-std=gnu17", "-O2", "-Wall", "-Wextra", "-Werror",
                   "-I", str(root / "include"), "-I", str(include),
                   str(fixture), "-o", str(executable)],
                check=True,
            )
            for scenario in ["empty", "retry-success", "remove-final"]:
                for direction in ["poweroff", "poweron"]:
                    expect_timeout = version == "old" and scenario == "remove-final"
                    try:
                        result = subprocess.run(
                            [str(executable), scenario, direction],
                            capture_output=True, text=True, timeout=1, check=True,
                        )
                    except subprocess.TimeoutExpired as error:
                        if not expect_timeout:
                            raise
                        # Prove the old process reached the intended interleaving.
                        assert b"contention then final control entry removed" in error.stdout
                        outcome = "expected timeout (1s); final entry removed"
                    else:
                        assert not expect_timeout, "old source unexpectedly completed"
                        assert "completed with expected passes" in result.stdout
                        outcome = "completed; pass/attempt assertions passed"
                    print(f"PASS {version} {scenario} {direction}: {outcome}", flush=True)


if __name__ == "__main__":
    main()
