#!/usr/bin/env bash
set -euo pipefail
SOURCE="${1:-/Volumes/George/containers/containers}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -d "$SOURCE" ]] || { echo "No container directory: $SOURCE" >&2; exit 1; }
mkdir -p "$REPO_ROOT/recipes" "$REPO_ROOT/manifests"
# Definition files are human-readable source files; never copy image binaries into git.
find "$SOURCE" -maxdepth 1 -type f -name '*.def' -exec cp -p {} "$REPO_ROOT/recipes/" \;
cd "$REPO_ROOT"
python3 scripts/scan_containers.py "$SOURCE" --manifest-dir "$REPO_ROOT/manifests"
echo "Prepared at $REPO_ROOT. Binary images remain at $SOURCE."
