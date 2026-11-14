# QAPA + Salmon Docker / Apptainer Image

## Overview

This container provides a reproducible environment for **QAPA (Quantification of Alternative Polyadenylation)** together with the external software required to build QAPA 3′UTR reference libraries and quantify alternative polyadenylation usage from RNA-seq data.

The image was created to solve a recurring reproducibility problem in QAPA analysis: QAPA depends simultaneously on Python packages, R packages, BEDTools, Salmon, and the UCSC `gtfToGenePred` utility. Installing those dependencies directly on an HPC system can be difficult because package versions conflict and cluster users often do not have administrative privileges. The container therefore freezes the major software dependencies into a portable `linux/amd64` environment that can be built locally with Docker and converted to an Apptainer/Singularity SIF for cluster execution.

The validated Docker image tag used in this project is:

```text
qapa-salmon:1.4.1
```

The corresponding Apptainer image is:

```text
qapa-salmon-amd64.sif
```

## Intended use

The image supports the complete QAPA reference-building and quantification workflow:

```text
GENCODE/Ensembl GTF
        |
        v
gtfToGenePred
        |
        v
QAPA build
        |
        v
QAPA 3′UTR BED / sequence library
        |
        v
QAPA fasta
        |
        v
Salmon index
        |
        v
paired-end RNA-seq FASTQ
        |
        v
Salmon quantification
        |
        v
QAPA quant
        |
        v
Poly(A) Usage (PAU) matrix
```

The container does **not** perform the project-specific statistical comparison automatically. In the associated analyses, QAPA generated PAU values and downstream R code was used to calculate group-level effect sizes and statistical tests.

## Image architecture

The image is built specifically for:

```text
linux/amd64
```

This is important when building on Apple Silicon (`arm64`) hardware. Docker's cross-platform build support is used so the resulting image is compatible with standard x86_64 Linux HPC nodes.

Example build:

```bash
docker build \
  --no-cache \
  --progress=plain \
  --platform=linux/amd64 \
  -t qapa-salmon:1.4.1 \
  .
```

## Base image and build strategy

The final corrected build uses a **multi-stage Docker build**.

The Salmon binary is copied from the official Salmon container:

```dockerfile
FROM combinelab/salmon:latest AS salmon_stage
```

The primary runtime image is:

```dockerfile
FROM python:3.9-slim-bookworm
```

This strategy was adopted after an earlier attempt to download a presumed Salmon binary archive failed because the requested asset filename did not exist. The multi-stage build avoids depending on an unstable external download URL and reuses the portable binary already packaged by the Salmon developers.

## Main software included

### QAPA

```text
QAPA version: 1.4.1
```

QAPA is installed from the tagged source release.

Conceptually:

```bash
git clone \
  --branch v1.4.1 \
  --depth 1 \
  https://github.com/morrislab/qapa.git

python -m pip install --no-deps /tmp/qapa
```

### Salmon

The final image uses the Salmon executable copied from the official Salmon container image.

Check the installed version at runtime:

```bash
docker run --rm \
  --platform=linux/amd64 \
  qapa-salmon:1.4.1 \
  salmon --version
```

### BEDTools

BEDTools is installed through Debian packages and is required by QAPA/pybedtools operations.

Validation:

```bash
bedtools --version
```

### UCSC `gtfToGenePred`

The UCSC `gtfToGenePred` binary is installed under:

```text
/usr/local/bin/gtfToGenePred
```

This program converts a GTF annotation into the genePred representation used during QAPA reference construction.

### R

The image contains R plus the R packages required by QAPA scripts, including:

```text
data.table
dplyr
optparse
rlang
stringr
testthat
```

### Python

The runtime is based on Python 3.9 and includes:

```text
NumPy
pandas
Biopython
pybedtools
```

The Dockerfile constrains the major Python libraries to version ranges compatible with QAPA.

## Why the final image avoids a single micromamba environment

An earlier design attempted to solve QAPA's Python, R, BEDTools, UCSC tools, and Salmon dependencies in one micromamba transaction. That approach introduced dependency-solving complexity and made build failures difficult to diagnose.

The final design uses:

```text
Debian apt packages -> R, R packages, BEDTools, system libraries
pip                -> QAPA Python dependencies
official image     -> Salmon executable
UCSC binary        -> gtfToGenePred
```

This reduces dependency-resolution coupling and makes failures easier to trace.

## Repository layout

A typical local build directory contains:

```text
Dockerfile
build.sh
build_with_log.sh
save_qapa_docker_archive.sh
convert_qapa_docker_to_sif.sh
README.md
```

## Building the Docker image

### Standard build

```bash
chmod +x build.sh
./build.sh
```

The script builds:

```text
qapa-salmon:1.4.1
```

for:

```text
linux/amd64
```

and immediately validates major executables.

### Manual build

```bash
docker build \
  --no-cache \
  --progress=plain \
  --platform=linux/amd64 \
  -t qapa-salmon:1.4.1 \
  .
```

### Save a complete build log

```bash
chmod +x build_with_log.sh
./build_with_log.sh
```

The build output is written to:

```text
qapa_docker_build.log
```

This log is useful for reproducibility, debugging, and provenance documentation.

## Build-time validation

The Dockerfile validates the environment before the image is accepted. The validation includes:

```bash
qapa --version
qapa --help
salmon --version
bedtools --version
gtfToGenePred
```

It also loads the required R packages and imports the required Python modules.

Example R validation:

```r
library(optparse)
library(stringr)
library(data.table)
library(dplyr)
```

Example Python validation:

```python
import Bio
import numpy
import pandas
import pybedtools
```

A failed dependency check causes the Docker build to fail rather than generating a partially functional image.

## Running with Docker

### Check QAPA

```bash
docker run --rm \
  --platform=linux/amd64 \
  qapa-salmon:1.4.1 \
  qapa --version
```

### Check Salmon

```bash
docker run --rm \
  --platform=linux/amd64 \
  qapa-salmon:1.4.1 \
  salmon --version
```

### Interactive shell

```bash
docker run --rm -it \
  --platform=linux/amd64 \
  -v "$PWD:/work" \
  qapa-salmon:1.4.1 \
  bash
```

The image uses:

```text
/work
```

as the default working directory.

## Converting to Apptainer / Singularity

The preferred HPC format is a SIF image.

On a Linux machine with Apptainer installed:

```bash
apptainer build \
  qapa-salmon-amd64.sif \
  docker-daemon:qapa-salmon:1.4.1
```

The resulting file can be copied to the cluster:

```bash
scp qapa-salmon-amd64.sif \
  gb3023@login1:/users/gb3023/nanopore-20250601/containers/
```

## Docker archive fallback

If direct Docker-to-SIF conversion is not available, save the image:

```bash
chmod +x save_qapa_docker_archive.sh
./save_qapa_docker_archive.sh
```

Expected output:

```text
qapa-salmon_1.4.1_linux-amd64.tar.gz
```

Where supported:

```bash
apptainer build \
  qapa-salmon-amd64.sif \
  docker-archive:qapa-salmon_1.4.1_linux-amd64.tar.gz
```

A pre-built SIF is preferable on clusters that prohibit container building.

## Example Apptainer invocation

```bash
module load apptainer

apptainer exec \
  --cleanenv \
  --bind /users/gb3023:/users/gb3023 \
  /users/gb3023/nanopore-20250601/containers/qapa-salmon-amd64.sif \
  qapa --version
```

## QAPA reference construction

A typical QAPA reference workflow is:

### 1. Convert GTF to genePred

```bash
gtfToGenePred \
  annotation.gtf \
  annotation.genePred
```

### 2. Build QAPA UTR annotation

For annotation-only reference construction:

```bash
qapa build \
  -N \
  ...
```

The exact arguments depend on the genome annotation and project directory structure.

### 3. Extract UTR sequences

```bash
qapa fasta \
  ...
```

### 4. Build Salmon index

```bash
salmon index \
  -t qapa_utrs.fa \
  -i salmon_index
```

## Quantification

Each RNA-seq sample is quantified against the QAPA UTR index.

Example:

```bash
salmon quant \
  -i salmon_index \
  -l A \
  -1 sample_R1.fastq.gz \
  -2 sample_R2.fastq.gz \
  -p 16 \
  -o sample_quant
```

QAPA then combines the Salmon results and calculates PAU values.

## Main outputs

The final QAPA table contains columns such as:

```text
APA_ID
Gene
Gene_Name
Num_Events
*.PAU
*.TPM
```

QAPA identifiers may end in:

```text
_P  proximal
_D  distal
_S  single
```

PAU represents the relative usage of an APA isoform within its gene.

## Important analytical caution

QAPA provides APA usage estimates but the final PAU table does not itself supply a project-specific differential-testing model. Any downstream t-test, linear model, effect-size threshold, FDR correction, or group comparison should be documented separately as part of the analysis workflow.

Low-expression isoforms can produce unstable PAU differences. Filtering by gene-level or isoform-level abundance is therefore recommended.

## Reproducibility notes

For every analysis, record:

```text
Docker image tag
SIF filename
Docker image digest if available
QAPA version
Salmon version
reference genome
annotation release
QAPA UTR library checksum
Salmon index source
sample manifest
command line
thread count
analysis date
```

## Troubleshooting

### `qapa: command not found`

Confirm image integrity:

```bash
docker run --rm qapa-salmon:1.4.1 qapa --version
```

or:

```bash
apptainer exec qapa-salmon-amd64.sif which qapa
```

### Salmon version mismatch

Always inspect:

```bash
salmon --version
```

The final build copies the Salmon binary from the official Salmon image, so the exact runtime version should be recorded in the analysis metadata.

### Apple Silicon build problems

Always specify:

```text
--platform=linux/amd64
```

during Docker build and test.

### `gtfToGenePred` missing

Check:

```bash
which gtfToGenePred
gtfToGenePred 2>&1 | head
```

### Bind-mounted files not visible in Apptainer

Explicitly bind the project root:

```bash
apptainer exec \
  --bind /users/gb3023:/users/gb3023 \
  qapa-salmon-amd64.sif \
  ...
```

## Provenance

This README documents the QAPA/Salmon image created for reproducible alternative-polyadenylation analysis and subsequent conversion to an HPC-compatible Apptainer SIF.

The image is intended as a reproducible research environment rather than a clinical or production diagnostic system.
