#!/usr/bin/env python3
"""Inventory local images, store exact digests, initialize (but never overwrite) provenance entries."""
import argparse
import csv
import hashlib
import sys
from pathlib import Path

EXTS = {'.sif': 'apptainer-sif', '.tar': 'tar-archive', '.def': 'apptainer-definition'}
PROJECTS = {
    'bedtools': 'BEDTools', 'bwa': 'BWA', 'dorado': 'Dorado',
    'fastqc': 'FastQC', 'isoquant': 'IsoQuant', 'labrat': 'LABRAT',
    'modkit': 'modkit', 'multiqc': 'MultiQC', 'qapa': 'QAPA + Salmon',
    'rmats-long': 'rMATS-long', 'rmats-salmon-star': 'rMATS + Salmon + STAR',
    'scape': 'scAPE', 'scutr': 'scUTR-quant', 'suppa': 'SUPPA',
    'ucsc': 'UCSC bedGraphToBigWig',
}


def hint(name):
    lower = name.lower()
    for prefix, project in sorted(PROJECTS.items(), key=lambda p: -len(p[0])):
        if lower.startswith(prefix):
            return project
    return 'Unclassified'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def read_tsv(path):
    if not path.exists():
        return []
    with path.open(newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f, delimiter='\t'))


def write_tsv(path, cols, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', newline='', encoding='utf-8') as f:
        wr = csv.DictWriter(f, fieldnames=cols, delimiter='\t', extrasaction='ignore')
        wr.writeheader()
        wr.writerows(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path, help='Directory containing .sif, .tar, .def')
    parser.add_argument('--manifest-dir', type=Path, default=Path('manifests'))
    args = parser.parse_args()
    if not args.source.is_dir():
        sys.exit(f'No such source directory: {args.source}')
    files = sorted(p for p in args.source.iterdir() if p.is_file() and p.suffix.lower() in EXTS)
    if not files:
        sys.exit('No .sif, .tar, .def files found in the source directory')
    inventory = []
    for i, p in enumerate(files, 1):
        print(f'[{i}/{len(files)}] SHA256 {p.name}', flush=True)
        inventory.append(dict(filename=p.name, format=EXTS[p.suffix.lower()],
                              size_bytes=p.stat().st_size, sha256=digest(p),
                              tool_hint=hint(p.name)))
    write_tsv(args.manifest_dir / 'inventory.tsv',
              ['filename', 'format', 'size_bytes', 'sha256', 'tool_hint'], inventory)
    provenance_path = args.manifest_dir / 'provenance.tsv'
    existing = {r['filename']: r for r in read_tsv(provenance_path) if r.get('filename')}
    cols = ['filename', 'upstream_project', 'upstream_url', 'origin', 'redistribution_permission', 'notes']
    records = []
    for info in inventory:
        name = info['filename']
        records.append(existing.get(name, dict(filename=name, upstream_project=info['tool_hint'],
                                               upstream_url='', origin='unverified',
                                               redistribution_permission='unverified', notes='')))
    # Keep any prior provenance entries for files temporarily absent from this scan.
    for name, record in existing.items():
        if name not in {r['filename'] for r in records}:
            records.append(record)
    write_tsv(provenance_path, cols, records)
    print(f'Wrote inventory for {len(files)} files to {args.manifest_dir / "inventory.tsv"}')
    print('Review provenance.tsv before making any container images public.')


if __name__ == '__main__':
    main()
