# Bioinformatics HPC containers

A curated inventory of bioinformatics software container images used or assembled for research on HPC systems, with build definitions where available, checksums, provenance fields, and (where permitted) downloadable release artifacts.

## Attribution and disclaimer

This repository contains a curated collection of Apptainer/Singularity
and Docker-compatible container images assembled, built, converted,
downloaded, or maintained for bioinformatics research and
high-performance computing (HPC) workflows.

**I am not the original developer or copyright holder of the
bioinformatics software packaged within these containers.**

All underlying software, trademarks, intellectual property, and
associated rights remain with their respective developers,
contributors, institutions, and organizations.

My contributions, where applicable, involve container preparation,
environment configuration, HPC compatibility, organization,
documentation, and reproducibility.

Users should acknowledge and cite the original software developers
and relevant publications. Refer to the upstream software projects
for official documentation, licenses, and updates.

**Redistribution notice:** Inclusion in this collection or approval
for repository staging does not independently establish permission
to redistribute third-party binaries. Each tool remains subject
to its applicable upstream license and distribution terms.

## Contents

The source directory contains Apptainer/Singularity `.sif` images, some `.tar` image archives, and two `.def` definition files. The files cover these tools/environments:

| Tool or environment | Container/recipe filenames (from original collection) |
| --- | --- |
| BEDTools | `bedtools.sif` |
| BWA | `bwa_0.7.18.sif` |
| Dorado | `dorado_latest.sif` |
| FastQC | `fastqc_0.12.1.sif` |
| IsoQuant | `isoquant.sif`, `isoquant-amd64.tar` |
| LABRAT | `labrat-amd64.sif`, `labrat-amd64.tar` |
| modkit | `modkit_latest.sif` |
| MultiQC | `multiqc_1.21.sif` |
| QAPA + Salmon | `qapa-salmon-amd64.sif` |
| rMATS-long | `rmats-long_v2.0.1.sif` |
| rMATS + Salmon + STAR | `rmats-salmon-star-amd64.sif`, `.tar` |
| scAPE | `scape.def` |
| scUTR-quant | `scutr-quant_0.5.0.sif` |
| SUPPA | `suppa.sif`, `suppa-amd64.tar`, `suppa.def` |
| UCSC bedGraphToBigWig | `ucsc-bedgraphtobigwig.sif` |

The filenames indicate intended tools and some versions, but **they do not independently verify the installed versions, architecture, authorship, contents, or provenance.** Consult `manifests/inventory.tsv` and `manifests/provenance.tsv` for the reviewed record.

## Repo layout

```text
.
├── .gitignore
├── README.md
├── recipes/                  # Copy of original .def files when available
├── manifests/
│   ├── inventory.tsv          # Generated sizes and SHA256 values
│   ├── provenance.tsv         # Human-reviewed origin and licensing information
│   └── redistribution_approved.txt  # Explicit file allowlist (empty by default)
└── scripts/
    ├── scan_containers.py
    ├── prepare_local.sh
    ├── init_github_repo.sh
    └── publish_approved_release.sh
```

## Prepare local inventory

Run from the cloned/extracted starter directory on the Mac where the images are stored:

```bash
bash scripts/prepare_local.sh /Volumes/George/containers/containers
```

This copies only available `.def` text recipes and computes checksums and sizes for `.sif`, `.tar`, and `.def`. It does not copy large image binaries into the repository. `manifests/provenance.tsv` is maintained separately so future inventory scans do not overwrite manual licensing reviews.

Review and fill in `manifests/provenance.tsv` with upstream project URLs, actual image origins, and distribution rights. The default status is `unverified`.

## Publish the Git repository

Check the GitHub CLI is authenticated (`gh auth status`). From the starter directory, run:

```bash
bash scripts/init_github_repo.sh gsarfo-boateng/bioinformatics-containers
```

This creates a **private** repository by default to allow an initial rights review. The script deliberately stops if the remote repository already exists, rather than risk overwriting it. Publish the repository when the attribution and provenance records have been reviewed.

## Publish container binaries (optional)

No container binary is published by default. After verifying a specific image's license and redistribution permission, enter its **exact filename** (one per line) in `manifests/redistribution_approved.txt` and set that image's `redistribution_permission` to `approved` in `manifests/provenance.tsv`. Then:

```bash
bash scripts/publish_approved_release.sh /Volumes/George/containers/containers container-snapshot-v1 gsarfo-boateng/bioinformatics-containers
```

The release script verifies filenames and SHA256 checksums, refuses images of 2 GiB or more, and uploads only explicitly approved files as GitHub Release assets. It checks the release tag before using it to avoid empty-tag errors. GitHub ordinary repository files are limited to 100 MiB, and single Release assets to less than 2 GiB.

Do not upload `dorado_latest.sif` as-is: it is approximately 8.7 GB (above the Release asset limit), and its redistribution terms must also be checked. Other images similarly require licensing review. For images that cannot be redistributed, retain only a recipe or a link to the official upstream distribution.

## Using the images

Apptainer/Singularity `.sif` images generally run on Linux HPC environments, for example:

```bash
apptainer exec fastqc_0.12.1.sif fastqc --version
```

The actual executable path and runscript depend on each image's contents. The `.tar` archives may be Docker image archives, but verify their format before attempting `docker load -i <file>`.

## Important limitations

- A `.sif` binary alone does not prove how, by whom, or from which source it was built.
- This repository is not an upstream mirror or an assertion of authorship or warranty.
- Original `.def` files can help reproducibility but may need refreshed bases, pinned versions, and validation before rebuilding.
- Some third-party licenses restrict packaging or redistribution; when unclear, link to the upstream source instead.
