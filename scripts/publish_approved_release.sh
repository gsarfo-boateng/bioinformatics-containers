#!/usr/bin/env bash
set -euo pipefail
SOURCE="${1:?Usage: publish_approved_release.sh SOURCE_DIR TAG OWNER/REPO}"
TAG="${2:?A non-empty release tag is required}"
REPO="${3:?An explicit owner/repository is required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v gh >/dev/null || { echo 'GitHub CLI required' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Python3 required' >&2; exit 1; }
gh auth status >/dev/null
[[ -d "$SOURCE" ]] || { echo "Missing source: $SOURCE" >&2; exit 1; }
[[ -f manifests/inventory.tsv && -f manifests/provenance.tsv && -f manifests/redistribution_approved.txt ]] || { echo 'Run prepare_local.sh first' >&2; exit 1; }
# Enforce both exact-name allowlist and explicit approved provenance status.
# Validate sha256 on the ORIGINAL binary, and size < 2 GiB per GitHub Release asset.
ASSET_LIST="$(mktemp)"; CHECKSUMS="$(mktemp)"
trap 'rm -f "$ASSET_LIST" "$CHECKSUMS"' EXIT
python3 - "$SOURCE" "$ASSET_LIST" "$CHECKSUMS" <<'PY'
import csv, hashlib, sys
from pathlib import Path
source, target_list, checksum_file = map(Path, sys.argv[1:])
base = Path('manifests')
with (base/'inventory.tsv').open(newline='') as f:
    inventory = {r['filename']: r for r in csv.DictReader(f, delimiter='\t')}
with (base/'provenance.tsv').open(newline='') as f:
    provenance = {r['filename']: r for r in csv.DictReader(f, delimiter='\t')}
allowed = [line.strip() for line in (base/'redistribution_approved.txt').read_text().splitlines()
           if line.strip() and not line.lstrip().startswith('#')]
if not allowed:
    sys.exit('No approved filenames: review licenses and update manifests/redistribution_approved.txt first.')
if len(set(allowed)) != len(allowed):
    sys.exit('Duplicate approved filenames; remove duplicates.')
assets = []
checks = []
for name in allowed:
    if name != Path(name).name or name.startswith('.'):
        sys.exit(f'Unsafe filename: {name}')
    image = source/name
    if not image.is_file() or image.is_symlink():
        sys.exit(f'Missing, or symlink not accepted: {image}')
    if image.suffix.lower() not in ('.sif', '.tar'):
        sys.exit(f'Only .sif and .tar binaries belong in release assets: {name}')
    if provenance.get(name, {}).get('redistribution_permission', '').strip().lower() != 'approved':
        sys.exit(f'No explicit redistribution approval in provenance.tsv for: {name}')
    if name not in inventory:
        sys.exit(f'Not in inventory.tsv: {name}')
    size = image.stat().st_size
    if size >= 2*1024**3:
        sys.exit(f'GitHub Release asset must be under 2 GiB: {name} ({size} bytes)')
    if str(size) != str(inventory[name]['size_bytes']):
        sys.exit(f'Size has changed; rerun prepare_local.sh: {name}')
    h = hashlib.sha256()
    with image.open('rb') as f:
        for block in iter(lambda: f.read(8*1024*1024), b''):
            h.update(block)
    digest = h.hexdigest()
    if digest != inventory[name]['sha256']:
        sys.exit(f'Checksum mismatch, rerun prepare_local.sh: {name}')
    assets.append(str(image.resolve()))
    checks.append(f'{digest}  {name}')
target_list.write_text('\n'.join(assets) + '\n')
checksum_file.write_text('\n'.join(checks) + '\n')
print(f'{len(assets)} license-approved assets verified (all individually below 2 GiB).')
PY
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Creating release $TAG for $REPO"
  gh release create "$TAG" --repo "$REPO" --target main \
    --title "Bioinformatics container snapshot $TAG" \
    --notes "Curated third-party bioinformatics container artifacts. Upstream software authors retain ownership and copyright; see README.md and manifests/provenance.tsv. Only explicitly reviewed assets are included."
fi
while IFS= read -r asset; do
  echo "Publishing $(basename "$asset")"
  gh release upload "$TAG" "$asset" --repo "$REPO" --clobber
done < "$ASSET_LIST"
# Add checksums as a separate, named temporary file, without tracking binaries in Git.
CHECKSUMS_NAMED="$(mktemp -d)/SHA256SUMS.txt"
trap 'rm -f "$ASSET_LIST" "$CHECKSUMS"; rm -f "$CHECKSUMS_NAMED"; rmdir "$(dirname "$CHECKSUMS_NAMED")"' EXIT
cp "$CHECKSUMS" "$CHECKSUMS_NAMED"
gh release upload "$TAG" "$CHECKSUMS_NAMED" --repo "$REPO" --clobber
gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name'
