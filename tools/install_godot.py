#!/usr/bin/env python3
"""Install a pinned official Linux editor and matching release template into a cache."""
import hashlib
import json
import os
import shutil
import urllib.request
import zipfile
from pathlib import Path


def main():
    version = json.loads(Path("release-config.json").read_text())["godot_version"]
    cache = Path.home() / ".cache/godot-release" / version
    cache.mkdir(parents=True, exist_ok=True)
    editor = cache / "godot"
    template = cache / "linux_release.x86_64"
    base = f"https://github.com/godotengine/godot-builds/releases/download/{version}-stable/"
    if not editor.exists() or not template.exists():
        checksums = urllib.request.urlopen(base + "SHA512-SUMS.txt").read().decode()
        expected = {line.split()[1]: line.split()[0] for line in checksums.splitlines() if len(line.split()) == 2}
        archives = []
        if not editor.exists():
            archives.append((f"Godot_v{version}-stable_linux.x86_64.zip", f"Godot_v{version}-stable_linux.x86_64", editor))
        if not template.exists():
            archives.append((f"Godot_v{version}-stable_export_templates.tpz", "templates/linux_release.x86_64", template))
        for filename, member, destination in archives:
            archive = cache / filename
            print("Downloading", filename, flush=True)
            urllib.request.urlretrieve(base + filename, archive)
            digest = hashlib.sha512()
            with archive.open("rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected[filename]:
                archive.unlink()
                raise RuntimeError("Official SHA-512 checksum mismatch: " + filename)
            with zipfile.ZipFile(archive) as zipped, zipped.open(member) as source, destination.open("wb") as target:
                shutil.copyfileobj(source, target)
            destination.chmod(0o755)
            archive.unlink()
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a") as output:
            output.write(f"GODOT={editor}\nGODOT_RELEASE_TEMPLATE={template}\n")
    print(editor)
    print(template)


if __name__ == "__main__":
    main()
