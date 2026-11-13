# Contributing

Create a `feature/…`, `fix/…`, or `chore/…` branch and open a pull request against
`main`. Do not push game changes directly to `main`. CI imports the project, runs
Python release-policy tests and Godot integration tests, exports Linux, and starts
the actual exported binary with isolated save data.

Use a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/) PR title.
PRs are squash-merged with that title as the commit subject:

- `fix(menu): restore keyboard focus` → patch, e.g. `0.1.0` → `0.1.1`.
- `feat(combat): add a basic attack` → minor, e.g. `0.1.1` → `0.2.0`.
- `feat(save)!: replace the save format` → major, e.g. `0.2.0` → `1.0.0`.
- A `BREAKING CHANGE:` footer also requests a major release.
- `perf` and `revert` request a patch. Documentation, tests, refactoring, build,
  CI, and chore changes do not publish a release unless marked breaking.

The first releasable commit produces **0.1.0**. Pushes to `main` run the full
pipeline and publish a GitHub Release when releasable changes exist. Releases
contain a Linux x86_64 ZIP, SHA-256 checksums, licenses, and generated notes.
The workflow uses the standard GitHub token; no personal token is needed.
Publication is serialized and happens only after checks and export succeed.

## Local checks and builds

```sh
python3 tools/install_godot.py
export GODOT="$HOME/.cache/godot-release/4.7.2/godot"
export GODOT_RELEASE_TEMPLATE="$HOME/.cache/godot-release/4.7.2/linux_release.x86_64"
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/check.py
python3 tools/build_release.py --version 0.1.0
```

`release-config.json` pins the engine, initial version, export preset, and test
scripts. The installer verifies official SHA-512 checksums and caches only the
editor and Linux release template. Export packages stamp their own version;
the tracked project files are restored after export. Git tags are the release
version authority; `version.txt` is the development/PR build default.

Keep source and technical documentation in English. Add UI messages to both
language columns in `i18n/messages.csv`. Never commit local saves, export
credentials, signing keys, or generated build artifacts.
