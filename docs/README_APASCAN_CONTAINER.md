# APA-Scan Apptainer Container and Patched HPC Runtime

## Overview

This container provides the runtime used for **APA-Scan**, a coverage-based alternative-polyadenylation analysis tool.

Confirmed container path in the project:

```text
/users/gb3023/nanopore-20250601/containers/apascan.sif
```

Confirmed application location inside the image:

```text
/opt/APA-Scan
```

Confirmed files include:

```text
/opt/APA-Scan/APA-Scan.py
/opt/APA-Scan/methods.py
/opt/APA-Scan/make_plots.py
/opt/APA-Scan/configuration.ini
```

The project also created a patched, project-local runtime copy of APA-Scan to modernize coverage generation and make parallel HPC execution safer.

> **Build provenance note**
>
> The retained project materials confirm the SIF and internal application paths but do not include the complete original Dockerfile used to produce `apascan.sif`. This README therefore documents the validated container runtime and the project-local patch layer without inventing an unverified base image or package manifest.

## Scientific purpose

APA-Scan identifies candidate shifts in alternative polyadenylation from RNA-seq alignment coverage around candidate 3′UTR polyadenylation positions.

Conceptually:

```text
coordinate-sorted RNA-seq BAMs
          |
          v
candidate transcript/3′UTR annotation
          |
          v
per-position coverage
          |
          v
upstream/downstream coverage ratios
          |
          v
condition comparison
          |
          v
candidate APA shifts
```

Unlike transcript-abundance methods such as QAPA or LABRAT, APA-Scan works directly from genomic alignment coverage.

## Annotation requirement used in this project

The retained source code checks for transcript identifiers beginning with:

```text
NM_
NR_
```

Therefore the project used a RefSeq/UCSC-style `refGene` annotation rather than directly supplying GENCODE `ENSMUST...` transcript IDs.

Example prepared annotation:

```text
mm39.refGene.apascan.txt
```

Typical fields include:

```text
name
chrom
strand
txStart
txEnd
cdsStart
cdsEnd
exonCount
exonStarts
exonEnds
name2
```

## Genome reference

The mouse project used:

```text
GRCm39
```

with a genome FASTA consistent with the chromosome names in the annotation and BAM files.

## Runtime discovery

The HPC wrapper does not assume that APA-Scan is installed in only one location. It searches several candidate paths:

```text
/opt/APA-Scan/APA-Scan.py
/opt/apascan/APA-Scan.py
/APA-Scan/APA-Scan.py
/app/APA-Scan.py
/usr/local/APA-Scan/APA-Scan.py
/workspace/APA-Scan/APA-Scan.py
```

If none are found, it searches the container filesystem for `APA-Scan.py`.

This allows the same wrapper to tolerate modest differences among container builds.

## Why a project-local patched copy is created

Rather than directly modifying the immutable SIF, the workflow:

1. locates the application inside the container;
2. copies the required source files into a writable project directory;
3. copies or links the available `samtools`;
4. patches the local `methods.py`;
5. runs the patched code through the container runtime.

This preserves the original container image while making the compatibility changes explicit and auditable.

## Modern `samtools mpileup` patch

The original APA-Scan implementation relied on the historical:

```text
samtools pileup
```

interface.

The project patch replaces this with the supported modern command:

```text
samtools mpileup
```

This was necessary because modern samtools distributions no longer support the older `pileup` behavior expected by the original code.

## Patched coverage generation

The patched `SamtoText()` function:

```text
creates an output directory per BAM
checks for a BAM index
creates the BAM index if absent
iterates over chromosomes
creates per-chromosome sparse coverage files
uses file locks
uses temporary files
writes completion markers
```

This makes coverage generation safer for parallel execution.

## File-locking protection

Parallel comparisons can request coverage for the same BAM/chromosome simultaneously.

To prevent race conditions, the patched workflow uses file locks:

```python
fcntl.flock(lock_handle, fcntl.LOCK_EX)
```

This ensures only one process creates a particular cached chromosome coverage file at a time.

## Completion markers

For each chromosome-level coverage cache, the patched runtime tracks a completion marker.

Conceptually:

```text
chr1.txt
chr1.txt.complete
chr1.txt.lock
```

A completed cache can be reused by later comparisons without regenerating the same coverage.

## BAM indexing

The patch checks common BAM-index locations:

```text
sample.bam.bai
sample.bai
```

If no index is found, it calls:

```bash
samtools index -@ <threads> sample.bam
```

## Environment controls

The patched runtime supports environment variables such as:

```text
APASCAN_SAMTOOLS
APASCAN_THREADS
```

This avoids hard-coding a single executable path.

## Running through Apptainer

Conceptual execution:

```bash
module load apptainer

apptainer exec \
  --cleanenv \
  --bind /users/gb3023:/users/gb3023 \
  /users/gb3023/nanopore-20250601/containers/apascan.sif \
  python3 /path/to/patched/APA-Scan.py \
  ...
```

The exact APA-Scan command-line arguments depend on the comparison configuration.

## Project configuration

The retained first-pass project configuration used:

```text
PAS-seq input = NULL
extended 3′UTR = no
All events = no
```

This means the analysis relied on RNA-seq coverage in annotated 3′UTRs rather than extending every terminal region by 10 kb.

## Group direction

In the associated project:

```text
input1 = experimental
input2 = WT
```

Therefore:

```text
Ratio Difference = ratio(input1) - ratio(input2)
                 = experimental - WT
```

## Main output fields

APA-Scan results can contain fields such as:

```text
Chrom
Gene
Strand
Start
End
Position
p-value
Ratio Difference
Absolute ratio difference
```

## Directional interpretation

For a conventional tandem-3′UTR candidate:

```text
Ratio Difference > 0
```

indicates relatively greater downstream/post-site coverage in the experimental condition and is consistent with increased distal usage / lengthening.

```text
Ratio Difference < 0
```

is consistent with reduced downstream coverage and increased proximal cleavage / shortening.

Because coverage geometry depends on strand and transcript architecture, high-priority events should be inspected against the annotation and coverage tracks before assigning a biological label.

## Statistical interpretation

The implementation provides a raw statistical comparison. In the associated downstream workflow, multiple-testing correction and an effect-size threshold were planned.

Example project criterion:

```text
FDR < 0.05
AND
|Ratio Difference| >= 0.10
```

This is a project-level criterion, not an inherent universal APA-Scan requirement.

## Input recommendations

Use:

```text
coordinate-sorted BAM
indexed BAM
splice-aware RNA-seq alignment
consistent chromosome naming
matched genome/annotation build
biological replicates
```

Avoid mixing:

```text
chr1 vs 1 chromosome naming
different genome builds
different annotation releases
partially generated cache directories
```

## Parallel execution

The project patch was explicitly designed to reduce conflicts when multiple APA comparisons are run in parallel.

Recommended practices:

```text
one job per biological comparison
shared read-only reference
shared cached BAM coverage only when protected by locks
comparison-specific result directories
explicit SLURM logs
```

## Validation checks

Before biological interpretation:

```text
confirm APA-Scan.py was found inside the SIF
confirm samtools is available
confirm BAMs are indexed
confirm annotation transcript identifiers match expected format
confirm chromosome naming matches
confirm result table is non-empty
confirm expected groups were assigned to input1/input2
inspect representative coverage plots
```

## Troubleshooting

### `samtools pileup` error

Use the patched workflow that calls:

```text
samtools mpileup
```

rather than the legacy `pileup` command.

### Empty or malformed coverage files

Check:

```text
BAM index
chromosome name
BAM readability
samtools executable
coverage cache completion marker
```

The patched reader was also designed to tolerate headerless sparse coverage files.

### Race conditions in parallel jobs

Use the patched version with file locking and per-file completion markers.

### APA-Scan does not recognize GENCODE transcript IDs

Use a compatible RefSeq/refGene-style annotation when required by the code path being executed.

### No output

Verify that:

```text
input BAMs contain aligned reads
annotation overlaps BAM chromosomes
comparison configuration is valid
output directory is writable
```

## Reproducibility metadata

Record:

```text
SIF filename
SIF checksum
Apptainer version
APA-Scan internal source path
patch version
patched methods.py checksum
samtools version
genome build
annotation source/version
BAM-generation pipeline
sample manifest
group definition
SLURM job ID
analysis date
```

## Scientific role of the container

The SIF provides a stable APA-Scan software environment, while the project-local patch layer documents compatibility changes needed for modern HPC execution. This separation is useful for reproducible research because the immutable upstream runtime and the explicit local modifications can be archived independently.

The container and workflow are intended for research use.
