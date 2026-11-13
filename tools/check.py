#!/usr/bin/env python3
"""Run imports and integration tests, treating Godot's logged errors as failures."""
import json
import os
import re
import subprocess
import sys


def run_godot(arguments, timeout=180):
    executable = os.environ.get("GODOT", "godot")
    result = subprocess.run([executable, "--headless", "--path", ".", *arguments], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    print(result.stdout, end="", flush=True)
    if result.returncode or re.search(r"^(?:SCRIPT )?ERROR:", result.stdout, re.MULTILINE):
        raise RuntimeError("Godot check failed: " + " ".join(arguments))


def main():
    config = json.load(open("release-config.json"))
    run_godot(["--editor", "--import"])
    for script in config["tests"]:
        run_godot(["--fixed-fps", "60", "--script", "res://" + script], timeout=60)


if __name__ == "__main__":
    main()
