# LABRAT + Salmon Apptainer Container

## Overview

This container provides a reproducible runtime for **LABRAT**, an alternative-polyadenylation analysis framework that quantifies relative usage of transcript 3′ ends.

The image used in the associated HPC workflows is:

```text
labrat-amd64.sif
```

Cluster location used in the project:

```text
/users/gb3023/nanopore-20250601/containers/labrat-amd64.sif
```

The retained project records confirm that the image contains both a LABRAT executable and a compatible Salmon installation. The runtime scripts dynamically locate those executables rather than assuming a single fixed command name.

> **Build provenance note**
>
> The original Dockerfile used to produce this SIF was not retained in the available project files used to prepare this README. Therefore this document does not invent an unverified base image, LABRAT version, or exact package manifest. Runtime behavior and workflow details below are based on the validated SIF and project scripts.

## Scientific purpose

LABRAT measures the relative use of alternative transcript 3′ ends and reports a gene-level **Ψ (psi)** score.

Conceptually:

```text
Ψ = 0  -> exclusive use of the most upstream APA site
Ψ = 1  -> exclusive use of the most downstream APA site
```

Therefore:

```text
higher Ψ -> greater downstream 3′-end usage
lower Ψ  -> greater upstream 3′-end usage
```

LABRAT supports multiple APA architectures, including:

```text
TUTR
ALE
mixed
```

where:

```text
TUTR  = tandem UTR APA
ALE   = alternative last exon
mixed = mixture of transcript-end architectures
```

## Workflow overview

The validated project workflow is:

```text
GENCODE GFF3 + genome FASTA
          |
          v
LABRAT makeTFfasta
          |
          v
terminal-fragment transcriptome
(TFseqs.fasta)
          |
          v
LABRAT runSalmon
          |
          v
LABRAT-specific Salmon quantification
          |
          v
sample_conditions.tsv
          |
          v
LABRAT calculatepsi
          |
          v
LABRAT.psis
LABRAT.psis.pval
numberofposfactors.txt
```

## Why LABRAT needs a dedicated Salmon workflow

LABRAT does not simply use a conventional whole-transcript Salmon index.

The workflow creates a dedicated terminal-fragment sequence library:

```text
TFseqs.fasta
```

and quantifies the RNA-seq samples against that LABRAT-specific reference.

Therefore standard Salmon `quant.sf` files generated for whole-transcript differential-expression analysis should **not** be substituted for LABRAT's terminal-fragment quantifications unless they were created from the correct LABRAT reference.

## Runtime validation

The project script validates the SIF before analysis.

It checks that the file exists and is readable:

```bash
[[ -f "$CONTAINER" ]]
[[ -r "$CONTAINER" ]]
```

The container is run with:

```bash
apptainer exec \
  --cleanenv \
  --bind "${BIND_ROOT}:${BIND_ROOT}" \
  "$CONTAINER" \
  ...
```

The script attempts to locate LABRAT using:

```bash
command -v LABRAT.py
command -v LABRAT
command -v labrat
```

and Salmon using:

```bash
command -v salmon
```

This makes the workflow robust to modest differences in executable naming.

## Salmon compatibility

The retained runtime script explicitly checks the Salmon version and warns if it is not in the commonly expected LABRAT-compatible `0.14.x` range.

Example:

```bash
salmon --version
```

If the returned version does not match `0.14.x`, the workflow issues a warning but continues because the image is treated as the dedicated LABRAT environment.

For reproducible use, record the actual output of:

```bash
apptainer exec labrat-amd64.sif salmon --version
```

## Reference requirements

The validated mouse project used:

```text
Genome: GRCm39
Annotation: GENCODE vM39 GFF3
```

Example reference files:

```text
GRCm39.primary_assembly.genome.fa
gencode.vM39.primary_assembly.annotation.gff3
```

LABRAT may also create or use a gffutils database corresponding to the GFF3 annotation.

## Terminal-fragment construction

The workflow builds the LABRAT transcript-fragment FASTA with:

```bash
LABRAT \
  --mode makeTFfasta \
  --gff annotation.gff3 \
  --genomefasta genome.fa \
  --lasttwoexons \
  --librarytype RNAseq
```

Expected output:

```text
TFseqs.fasta
```

The `--lasttwoexons` configuration was used in the retained project workflow.

## Salmon quantification

LABRAT's `runSalmon` mode is given the paired-end read files and sample names.

Conceptual example:

```bash
LABRAT \
  --mode runSalmon \
  --librarytype RNAseq \
  --txfasta TFseqs.fasta \
  --reads1 sample1_R1.fastq.gz,sample2_R1.fastq.gz \
  --reads2 sample1_R2.fastq.gz,sample2_R2.fastq.gz \
  --samplename sample1,sample2 \
  --threads 16
```

The workflow checks that every sample produces:

```text
<salmon_dir>/<sample>/quant.sf
```

before proceeding.

## Condition table

LABRAT requires a sample-to-condition table.

Example:

```text
sample          condition
WT_mock_rep1    WT
WT_mock_rep2    WT
WT_mock_rep3    WT
U1_mock_rep1    U1_OE
U1_mock_rep2    U1_OE
U1_mock_rep3    U1_OE
```

## Differential APA calculation

The validated project used:

```bash
LABRAT \
  --mode calculatepsi \
  --salmondir "$SALMON_DIR" \
  --sampconds sample_conditions.tsv \
  --conditionA WT \
  --conditionB U1_OE \
  --gff annotation.gff3 \
  --librarytype RNAseq
```

LABRAT defines:

```text
deltapsi = conditionB - conditionA
```

Therefore, when:

```text
conditionA = WT
conditionB = experimental
```

then:

```text
ΔΨ = experimental - WT
```

## Biological interpretation

For simple tandem-3′UTR events:

```text
ΔΨ > 0
```

is generally consistent with increased use of downstream/distal sites and 3′UTR lengthening.

```text
ΔΨ < 0
```

is generally consistent with increased upstream/proximal usage and 3′UTR shortening.

For `ALE` and some `mixed` events, report the result primarily as an upstream/downstream transcript-end shift unless the transcript structure has been directly inspected.

## Main output files

### `LABRAT.psis`

Contains sample-level psi measurements.

### `LABRAT.psis.pval`

Primary differential APA results.

Common fields include:

```text
Gene
sample-level psi columns
genetype
deltapsi
pval
FDR
```

### `numberofposfactors.txt`

Auxiliary LABRAT output generated during APA calculation.

## Significance definition used in the downstream project

The downstream project commonly used:

```text
FDR < 0.05
AND
|ΔΨ| >= 0.10
```

This threshold is a project-level interpretation criterion and should not be confused with a universal LABRAT requirement.

## Recommended Apptainer execution pattern

```bash
module load apptainer/1.3.5

CONTAINER="/users/gb3023/nanopore-20250601/containers/labrat-amd64.sif"

apptainer exec \
  --cleanenv \
  --bind /users/gb3023:/users/gb3023 \
  "$CONTAINER" \
  /bin/bash -lc 'command -v LABRAT.py || command -v LABRAT || command -v labrat'
```

Check Salmon:

```bash
apptainer exec \
  --cleanenv \
  --bind /users/gb3023:/users/gb3023 \
  "$CONTAINER" \
  salmon --version
```

## SLURM integration

Example resource request used in the project:

```bash
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=120:00:00
```

Actual resource needs depend on the number of samples, size of FASTQ files, and reference-generation requirements.

## Apptainer temporary/cache configuration

For large jobs, the project set:

```bash
export APPTAINER_TMPDIR="${SLURM_TMPDIR:-${WORKDIR}/apptainer_tmp}"
export APPTAINER_CACHEDIR="${WORKDIR}/apptainer_cache"
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"
export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
```

This avoids filling small default temporary locations.

## Input validation

The workflow validates:

```text
genome FASTA exists and is non-empty
GFF3 exists and is non-empty
FASTQ directory exists
every R1 exists and is non-empty
every R2 exists and is non-empty
sample manifest is internally consistent
```

A project manifest is written containing:

```text
sample
condition
replicate
accession
R1 path
R2 path
```

This is an important reproducibility feature.

## Resume behavior

The workflow reuses major intermediate outputs when they already exist.

For example:

```text
TFseqs.fasta
sample quant.sf files
LABRAT.psis.pval
```

This avoids unnecessary recomputation.

Partial Salmon output directories are removed before a clean rerun to reduce the risk of mixing incomplete and complete quantifications.

## Recommended provenance metadata

For each LABRAT analysis, preserve:

```text
SIF filename
SIF checksum
Apptainer version
LABRAT executable path
LABRAT version if available
Salmon version
reference genome build
GFF3 release
TFseqs.fasta checksum
sample manifest
sample_conditions.tsv
SLURM job script
thread count
analysis date
```

## Troubleshooting

### LABRAT executable not found

Inspect the image:

```bash
apptainer exec labrat-amd64.sif \
  /bin/bash -lc 'command -v LABRAT.py || command -v LABRAT || command -v labrat'
```

### Salmon executable not found

```bash
apptainer exec labrat-amd64.sif which salmon
```

### Wrong Salmon index

Do not use a normal transcriptome Salmon index. Rebuild or reuse the LABRAT terminal-fragment reference derived from `TFseqs.fasta`.

### Missing `quant.sf`

Check FASTQ paths, sample names, file permissions, and whether LABRAT `runSalmon` terminated early.

### `NA` psi values

Genes can fail LABRAT's expression or quantification requirements. `NA` values should not automatically be interpreted as biological absence of APA.

### Inconsistent direction

Always verify the condition order:

```text
deltapsi = conditionB - conditionA
```

## Reproducibility significance

The dedicated SIF makes an otherwise dependency-sensitive legacy APA workflow portable across HPC jobs. It allows LABRAT and its compatible Salmon runtime to be invoked from a fixed image while keeping the research data, references, metadata, and outputs outside the container.

This container is intended for research use and does not itself provide clinical interpretation.
