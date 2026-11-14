# SCAPE Docker Image Build Environment

## Overview

This README documents the Docker environment that was developed to package **SCAPE** and its legacy scientific dependencies into a portable `linux/amd64` container suitable for conversion to Apptainer/Singularity.

The retained build record shows the image was built or attempted under the tag:

```text
scape:latest
```

using:

```bash
docker build \
  --no-cache \
  --progress=plain \
  --platform=linux/amd64 \
  -t scape:latest \
  .
```

> **Important provenance status**
>
> The retained file contains a detailed **failed Docker build log** from the SCAPE image-development process. It confirms the intended dependency stack and base image, but it does **not** establish that this particular Dockerfile completed successfully. The documented failure was a network/download timeout during micromamba package retrieval. Therefore this README distinguishes the intended image specification from a confirmed final image.
>
> If a later successful SCAPE image exists on the workstation or cluster, its `docker inspect`, `apptainer inspect`, package versions, and checksum should be added to the provenance section below.

## Why SCAPE was containerized

SCAPE depends on an older Python/R software stack. Installing these versions directly into a modern HPC operating system can create compatibility problems.

The container was designed to isolate those legacy dependencies while producing an x86_64 Linux environment that can run on standard HPC nodes.

## Target architecture

The intended target is:

```text
linux/amd64
```

This is particularly important when building on Apple Silicon.

Build with:

```bash
--platform=linux/amd64
```

## Base image

The retained build log identifies:

```text
mambaorg/micromamba:1.5.8-focal
```

as the Docker base image.

This provides:

```text
Ubuntu Focal-based userspace
micromamba package manager
isolated Conda-compatible environment support
```

## Intended environment name

The Dockerfile creates a micromamba environment named:

```text
scape
```

under a prefix consistent with:

```text
/opt/conda/envs/scape
```

## Intended dependency stack

The retained Docker build log lists the following pinned packages:

```text
python=3.7.3
git
bedtools=2.26.0
pip
click=6.7
loguru=0.3.2
numpy=1.17.2
pandas=0.23.4
scipy=1.3.1
tqdm=4.26.0
pysam=0.15.4
pybedtools=0.8.1
r-base=3.6.3
rpy2=3.4.5
```

These version pins are important because SCAPE was developed against an older ecosystem and newer replacements may not be API-compatible.

## Conda channels

The build uses:

```text
conda-forge
bioconda
```

## Network-reliability configuration

The Dockerfile attempted to increase micromamba network tolerances through settings for:

```text
remote_connect_timeout_secs
remote_read_timeout_secs
remote_max_retries
extract_threads
```

The goal was to make dependency downloads more reliable during a large environment solve/install.

## Recorded build failure

The retained build log shows that micromamba began a transaction of approximately:

```text
333 MB
```

but failed while downloading:

```text
xorg-libxext
```

from conda-forge.

The key error was:

```text
Download error (28) Timeout was reached
Operation too slow
```

This indicates an external network/download failure rather than a demonstrated incompatibility in the SCAPE source code itself.

## Recommended modern build strategy

Because the retained build failed during a large single micromamba transaction, a more robust rebuild should use one of the following approaches:

### Option 1: Retry with package cache

Use a persistent BuildKit cache or local Conda package cache so completed downloads do not have to restart.

### Option 2: Pre-lock the environment

Resolve the legacy environment once and archive an explicit package specification.

### Option 3: Split dependency installation

Install the most difficult compiled packages first, then install the remaining Python-only packages in a second layer.

### Option 4: Use a pre-existing compatible environment as the source

If a validated SCAPE environment already exists, package that environment into a reproducible image rather than re-solving all historical dependencies.

## Example build command

```bash
docker build \
  --no-cache \
  --progress=plain \
  --platform=linux/amd64 \
  -t scape:latest \
  .
```

## Validation required after a successful build

A successful future image should not be considered validated until the following are checked:

```bash
docker run --rm \
  --platform=linux/amd64 \
  scape:latest \
  python --version
```

Expected target:

```text
Python 3.7.x
```

Check BEDTools:

```bash
docker run --rm \
  --platform=linux/amd64 \
  scape:latest \
  bedtools --version
```

Check R:

```bash
docker run --rm \
  --platform=linux/amd64 \
  scape:latest \
  R --version
```

Check Python libraries:

```bash
docker run --rm \
  --platform=linux/amd64 \
  scape:latest \
  python - <<'PY'
import click
import loguru
import numpy
import pandas
import scipy
import tqdm
import pysam
import pybedtools
import rpy2

print("SCAPE dependency imports successful")
PY
```

The SCAPE executable/module itself should also be invoked on a minimal test dataset.

## Converting a validated image to Apptainer

After Docker validation:

```bash
apptainer build \
  scape-amd64.sif \
  docker-daemon:scape:latest
```

Copy to the cluster:

```bash
scp scape-amd64.sif \
  gb3023@login1:/users/gb3023/nanopore-20250601/containers/
```

## Running on HPC

Conceptual pattern:

```bash
module load apptainer

apptainer exec \
  --cleanenv \
  --bind /users/gb3023:/users/gb3023 \
  scape-amd64.sif \
  <scape-command> ...
```

The exact SCAPE command and project-specific inputs should be documented with the final successful runtime.

## Recommended provenance record for a successful image

Once the successful image is located or rebuilt, record:

```text
Docker image tag
Docker image ID
Docker image digest
Dockerfile checksum
base image digest
SCAPE source version / git commit
Python version
R version
BEDTools version
pysam version
pybedtools version
rpy2 version
build date
build host architecture
SIF filename
SIF SHA256 checksum
Apptainer version used for conversion
minimal validation dataset
validation command
validation result
```

## Why this container still matters despite the failed retained build

The build history documents deliberate engineering to make a dependency-sensitive APA tool reproducible on modern infrastructure. The legacy version pins show why a container is preferable to installing SCAPE directly into a shared contemporary HPC environment.

For NIW or reproducibility documentation, use the **successful final image and its validation evidence** if available. The failed build log is useful as engineering provenance but should not be presented as proof that the final image itself was functional.

## Status

Based on the retained build evidence used for this README:

```text
Dockerfile design: documented
linux/amd64 target: documented
base image: documented
dependency pins: documented
build attempt: documented
specific failure: network timeout
successful completion of this exact build: not established by retained source
```

Update this section when the final successful SCAPE image is verified.
