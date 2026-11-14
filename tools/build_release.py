#!/usr/bin/env python3
"""Export a versioned Linux ZIP with notices and SHA-256 checksums."""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from check import run_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("Version must be MAJOR.MINOR.PATCH")
    config = json.loads(Path("release-config.json").read_text())
    slug = config["slug"]
    folder = Path("build") / f"{slug}-{args.version}-linux-x86_64"
    folder.mkdir(parents=True, exist_ok=True)
    executable = folder / (slug + ".x86_64")
    version_file = Path("version.txt")
    preset_file = Path("export_presets.cfg")
    original_version = version_file.read_bytes()
    original_presets = preset_file.read_bytes()
    try:
        version_file.write_text(args.version + "\n")
        template = os.environ.get("GODOT_RELEASE_TEMPLATE")
        if template:
            preset_file.write_text(original_presets.decode().replace('custom_template/release=""', 'custom_template/release=' + json.dumps(str(Path(template).resolve()))))
        run_godot(["--export-release", config["export_preset"], str(executable.resolve())], timeout=300)
    finally:
        version_file.write_bytes(original_version)
        preset_file.write_bytes(original_presets)
    # Run the actual exported binary with isolated user data, not just the editor.
    with tempfile.TemporaryDirectory(prefix="godot-export-smoke-") as user_data:
        env = {**os.environ, "XDG_DATA_HOME": user_data}
        result = subprocess.run([str(executable.resolve()), "--headless", "--quit-after", "20"], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
        print(result.stdout, end="")
        if result.returncode or re.search(r"^(?:SCRIPT )?ERROR:", result.stdout, re.MULTILINE):
            raise RuntimeError("Exported binary smoke test failed")
    for filename in ["LICENSE", "THIRD_PARTY_NOTICES.md"]:
        shutil.copy(filename, folder)
    shutil.copytree("licenses", folder / "licenses", dirs_exist_ok=True)
    for pack in Path("assets").glob("*/License.txt"):
        shutil.copy(pack, folder / "licenses" / (pack.parent.name + "_LICENSE.txt"))
    (folder / "RUN.txt").write_text(f"{config['title']} v{args.version}\n\nRun ./{executable.name}\nWASD / arrows: move. Escape: return to characters.\nApproach the skeleton to exchange automatic basic attacks.\nClick / Tab: optionally select a target.\nGreen health bar: player. Red health bar: enemy.\nHold the middle mouse button and drag: orbit the camera.\nMouse wheel up/down: zoom in/out.\nSelect English or Español in the language menu.\n")
    archive = Path("build") / (folder.name + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zipped:
        for file in sorted(folder.rglob("*")):
            if file.is_file():
                zipped.write(file, file.relative_to(folder.parent))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (Path("build") / "SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n")
    print("Built", archive)


if __name__ == "__main__":
    main()
