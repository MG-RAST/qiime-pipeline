# Maintainer Guide

Operational and release concerns. Code internals are in
[DEVELOPER.md](DEVELOPER.md); the pipeline reference is in
[PIPELINE.md](PIPELINE.md).

## Runtime environment

- **QIIME 2** must be on `PATH` (`conda activate scope-env`, or a QIIME 2
  amplicon distribution). The pipeline shells out to native `qiime` with no path
  resolution.
- Also required on `PATH`: **`wget`** (classifier download during `setup`) and
  **`biom`** (rel-abundance TSV export).
- **Python 3** for `qiime-console.py` (uses f-strings, `argparse`; bytecode under
  `scripts/__pycache__/` is 3.12).
- Scratch space: DADA2/demux are I/O heavy — see `resolve_tmpdir` and
  `MIN_TMP_FREE_GB = 50` in the driver.

## Classifier provisioning

`setup` fetches the Greengenes 13-8 515F/806R naive-Bayes classifier via `wget`:

```
https://data.qiime2.org/classifiers/sklearn-1.4.2/greengenes/gg-13-8-99-515-806-nb-classifier.qza
```

The URL is **pinned to sklearn 1.4.2** — it must match the scikit-learn version in
the QIIME 2 environment, or `classify-sklearn` will error. When bumping QIIME 2,
update this URL to the matching `sklearn-<ver>` path. No `.qza` classifiers are
committed to the repo.

## Docker images (all legacy QIIME 1 / Python 2.7)

| File | Base | Notes |
|---|---|---|
| `Dockerfile` (root) | `ubuntu:18.04` | Active image; installs cwltool + QIIME 1 + matplotlib 2.0.2 (patched TkAgg→Agg) |
| `Docker/Dockerfile.1.0.20180820141117` | — | Pinned cwltool build, matplotlib 2.0.2 |
| `Docker/Dockerfile.1.1.20180820141117` | — | Same, matplotlib 1.5.3 |
| `Docker/qiime.dockerfile` | `ubuntu:latest` | Heavier apt set; `pip install cwltool qiime` |

The CWL v1 tools instead reference the external image `mgrast/qiime:1.0`. Note:
**there is no Docker image for the QIIME 2 Python pipeline** — it runs from the
conda/QIIME 2 environment. `Docker/README.md` documents the
`major.minor.build(date)` version scheme.

## Repo housekeeping

- **Submodule:** `.gitmodules` declares `ebi-metagenomics-cwl` (the CWL tooling's
  upstream); it is **not checked out** (`git submodule status` shows it
  uninitialized). Init only if you need to regenerate CWL wrappers.
- **Tests:** only CWL job-input YAMLs under `tests/jobs/` — there is no test
  runner or assertion framework, and referenced fixture data isn't committed.
- **Docs drift guard:** `scripts/check_docs_tables.py` verifies the PIPELINE.md
  tables still match the code; run it in CI or before tagging.

## Release / versioning

- Docker images follow `major.minor.build` where build is a timestamp
  (`Docker/README.md`).
- No formal tag/release process for the Python pipeline today; changes land via
  PRs to `master` (see the `deliverable/MANIFEST.txt` for per-run QIIME version
  capture instead of a pipeline version string).

## Roadmap

- **QIIME 2 CWL port** is in progress: `CWL/Tools/qiime2/import.cwl` and
  `scripts/wf.1.0.cwl` are the seed; `scripts/wf.1.2.cwl` is an empty stub.
- Consolidating the legacy QIIME 1 CWL and the shell scripts as the Python driver
  becomes the single source of truth.
