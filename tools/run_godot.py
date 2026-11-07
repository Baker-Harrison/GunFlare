"""Run a Godot command and fail on a script error.

Godot can print a script error and still exit with code 0. A test that stops
on an error then reports no failure. This wrapper stops that problem.

Use: python tools/run_godot.py [--timeout SECONDS] -- godot --headless ...
"""

from __future__ import annotations

import argparse
import subprocess
import sys

BAD_TEXT = (
    "SCRIPT ERROR:",
    "Parse Error:",
    "Compile Error:",
    "Failed to load script",
    "SCRIPT LOAD FAILED",
)


def find_problems(lines: list[str]) -> list[str]:
    return [line.rstrip() for line in lines if any(text in line for text in BAD_TEXT)]


def self_test() -> int:
    good = ["Loading", "128 checks, 0 failures"]
    bad = good + ["SCRIPT ERROR: Invalid call. Nonexistent function 'x' in base 'Nil'."]
    if find_problems(good):
        print("self-test failed: good output has a problem")
        return 1
    if len(find_problems(bad)) != 1:
        print("self-test failed: a script error was not found")
        return 1
    print("run_godot self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=0.0)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("give a command after --")
    lines: list[str] = []
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    try:
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            lines.append(line)
        code = process.wait(timeout=args.timeout or None)
    except subprocess.TimeoutExpired:
        process.kill()
        print(f"The command did not stop in {args.timeout} seconds.")
        return 1
    problems = find_problems(lines)
    if problems:
        print("The run printed script errors:")
        for problem in problems:
            print("  " + problem)
        return 1
    if code != 0:
        print(f"The command stopped with exit code {code}.")
        return code
    return 0


if __name__ == "__main__":
    sys.exit(main())
