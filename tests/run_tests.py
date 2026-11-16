#!/usr/bin/env python3
"""
Headless test runner. Bundles every Luau source in ./src together with the Roblox mock
(tests/mock/roblox.lua) and a test script, then executes it with the `luau` CLI.

    python3 tests/run_tests.py                # runs all tests/*_test.lua
    LUAU=/path/to/luau python3 tests/run_tests.py

Get the CLI from https://github.com/luau-lang/luau/releases (luau-<os>.zip).
"""

import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
TESTS = os.path.join(ROOT, "tests")
LUAU = os.environ.get("LUAU", "luau")


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def bundle():
    entries = []
    for path in sorted(glob.glob(os.path.join(SRC, "**", "*.lua"), recursive=True)):
        rel = os.path.relpath(path, SRC).replace(os.sep, "/")
        with open(path, encoding="utf-8") as f:
            entries.append("[%r] = %s," % (rel, long_string(f.read())))
    return "local BUNDLE = {\n" + "\n".join(entries) + "\n}\n"


def main():
    with open(os.path.join(TESTS, "mock", "roblox.lua"), encoding="utf-8") as f:
        mock = f.read()
    with open(os.path.join(TESTS, "mock", "harness.lua"), encoding="utf-8") as f:
        harness = f.read()
    out_dir = os.path.join(TESTS, ".build")
    os.makedirs(out_dir, exist_ok=True)
    failed = 0
    tests = sorted(glob.glob(os.path.join(TESTS, "*_test.lua")))
    if len(sys.argv) > 1:
        tests = [t for t in tests if any(a in t for a in sys.argv[1:])]
    for test in tests:
        with open(test, encoding="utf-8") as f:
            body = f.read()
        program = (
            bundle()
            + "local M = (function()\n" + mock + "\nend)()\n"
            + "M.readFile = function(p) return BUNDLE[p] end\n"
            + "local H = (function()\n" + harness + "\nend)()\n"
            + body
        )
        out = os.path.join(out_dir, os.path.basename(test))
        with open(out, "w", encoding="utf-8") as f:
            f.write(program)
        print("=== " + os.path.basename(test))
        proc = subprocess.run([LUAU, out], capture_output=True, text=True)
        sys.stdout.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        if proc.returncode != 0 or "FAILED" in proc.stdout or "[MOCK ERROR]" in proc.stdout:
            failed += 1
    print("\n%d test file(s), %d failed" % (len(tests), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
