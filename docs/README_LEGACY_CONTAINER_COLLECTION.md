# Bioinformatics Container README Collection

This folder contains detailed documentation for the containerized environments developed or used in the RNA/APA workflows.

## Files

- `README_QAPA_SALMON_CONTAINER.md` — QAPA 1.4.1 + Salmon Docker image and SIF conversion.
- `README_LABRAT_CONTAINER.md` — LABRAT + compatible Salmon Apptainer runtime and HPC workflow.
- `README_APASCAN_CONTAINER.md` — APA-Scan SIF, modern `samtools mpileup` patch layer, caching, and HPC execution.
- `README_SCAPE_CONTAINER.md` — SCAPE Docker build specification and retained build-provenance status.

## Provenance policy

The READMEs distinguish:
1. confirmed image/runtime details,
2. project-specific workflow choices,
3. retained build history,
4. information that could not be verified from the available project records.

No unknown container version or dependency is silently invented.
