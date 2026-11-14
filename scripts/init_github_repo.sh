#!/usr/bin/env bash
set -euo pipefail
REPO="${1:-gsarfo-boateng/bioinformatics-containers}"
VISIBILITY="${2:---private}"
[[ "$VISIBILITY" == '--private' || "$VISIBILITY" == '--public' ]] || { echo 'Visibility must be --private or --public' >&2; exit 2; }
command -v gh >/dev/null || { echo 'Install GitHub CLI (gh) first.' >&2; exit 1; }
command -v git >/dev/null || { echo 'Git is required.' >&2; exit 1; }
gh auth status >/dev/null
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "Repository $REPO already exists. Not modifying an existing remote automatically." >&2
  echo "Clone it and copy this starter's README.md, scripts/, manifests/, recipes/, and .gitignore to the clone." >&2
  exit 1
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ -d .git ]]; then
  echo 'This directory already has .git; inspect git status and remotes before proceeding.' >&2
  exit 1
fi
git init -b main
git add .gitignore README.md scripts/ manifests/ recipes/
if git diff --cached --name-only | grep -E '\.(sif|simg|tar|tar\.gz)$'; then
  echo 'ERROR: binary artifacts staged; aborting.' >&2
  exit 1
fi
git commit -m 'Document bioinformatics HPC container inventory and provenance'
gh repo create "$REPO" "$VISIBILITY" --source=. --remote=origin --push
printf 'Created %s. Inspect README, provenance, and visibility before publishing any binaries.\n' "$REPO"
