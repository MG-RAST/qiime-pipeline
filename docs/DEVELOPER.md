# Developer Guide

Code architecture of the QIIME 2 pipeline and how to extend it. Operational
concerns (environment, releases, Docker) are in [MAINTAINER.md](MAINTAINER.md);
the tool/output reference is in [PIPELINE.md](PIPELINE.md).

## Entry point

Everything runs through [`scripts/qiime-console.py`](../scripts/qiime-console.py),
an argparse CLI. `bin/qiime` → `scripts/qiime-consol.py` → `qiime-console.py`
(two symlinks; note the truncated middle name).

### Subcommands

| Command | Function | Purpose |
|---|---|---|
| `setup <src> <base>` | `stage_data` | Discover/rename raw FASTQ, copy mapping, fetch classifier |
| `run workflow <base>` | `run_workflow` | Full pipeline (chains all stages + auto-package) |
| `run demux <base>` | `demux_data` | Standalone import + demux + summarize |
| `run denoise <base>` | `denoise_data` | Standalone DADA2 denoise-paired |
| `package <base>` | `package_results` | Build the shareable deliverable + manifest |
| `tool <name> <args…>` | `run_tool` | Thin passthrough to `qiime <name> …` |

## The `input`/`output` + `link_output` pattern

Steps write to `output/` and read from `input/`. `link_output(src, input_dir)`
symlinks each new `output/` artifact back into `input/` by basename, so the next
step finds it in `input/`. It uses `os.path.lexists` to detect and replace stale
or dangling symlinks from prior runs (rather than crashing on `FileExistsError`).

## Stage functions (call order)

`run_workflow` (the orchestrator) runs, in order:

1. import → demux (`demux_data`-equivalent inline) → dada2 denoise → feature-table
   summarize / tabulate-seqs / stats tabulate.
2. **`run_phylogeny_analysis`** — despite the name, this runs the tree
   (`align-to-tree-mafft-fasttree`) **and** a second `tabulate-seqs`
   (`rep-seqs.qzv`), `classify-sklearn` (`taxonomy.qza`), taxonomy tabulate, and
   the taxa barplot. Taxonomy therefore runs *before* diversity.
3. **`run_diversity_analysis`** — `core-metrics-phylogenetic`, three
   `alpha-group-significance` calls, `alpha-rarefaction`, `beta-group-significance`
   (one per `--beta-diversity-group-by` column).
4. **`run_relative_abundance_of_taxonomy`** — `taxa collapse` levels 1–7,
   `relative-frequency`, export, `biom convert`.
5. **`package_results`** (+ `write_manifest`) — best-effort, wrapped so a
   packaging failure never fails an otherwise-complete run.

> **Gotcha — `alpha-rarefaction` is coded twice, runs once.** Both
> `run_phylogeny_analysis` and `run_diversity_analysis` call it with the same
> `output/alpha-rarefaction-results/` dir. Phylogeny runs first, so the diversity
> call hits the skip-if-exists guard. If you ever "fix" one call, understand the
> other is dead code, not a second run.

## Packaging internals

- `DELIVERABLE_FILES` / `DELIVERABLE_DIRS` (module constants) define the curated
  export set; entries may be a list of alternative paths (first existing wins) to
  tolerate layout drift (e.g. flat `demux-full.qzv` vs `demux/demux-full.qzv`).
- `package_results` clears `deliverable/` before rebuilding (no stale files),
  validates `--format`, and for `--format tar` removes the staging folder.
- `write_manifest` checksums every bundled file (md5), records run params +
  QIIME version, and is written before the tarball so it's archived.

## Other internals

- **`resolve_tmpdir`** — picks a roomy, disk-backed temp dir and exports
  `TMPDIR`/`TMP`/`TEMP` so native `qiime` inherits it. Precedence: `--tmpdir` >
  `$QIIME_TMPDIR` > `$TMPDIR` (if not tmpfs) > `/scratch/tmp/qiime` > `<base>/tmp`.
  Warns below `MIN_TMP_FREE_GB = 50`.
- **Metadata columns** — `read_metadata_columns` strips per-field whitespace and a
  leading `#`; `resolve_metadata_column` does exact-then-fuzzy matching so
  `--beta-diversity-group-by` typos fail fast before demux/dada2.

## How to add a step

1. Write the artifact to `output/` with a skip-if-exists guard.
2. `link_output(new_artifact, input_dir)` (guard the link if the step can fail
   and skip producing the file).
3. If it should be shared, add it to `DELIVERABLE_FILES`/`DELIVERABLE_DIRS`.
4. Add a row to both tables in [PIPELINE.md](PIPELINE.md) and re-run
   `scripts/check_docs_tables.py`.

## Parallel implementations & the two-generation split

The repo carries two generations of the pipeline:

- **QIIME 2 (current):** `scripts/qiime-console.py` (authoritative), the shell
  scripts (`data-analysis-wf.sh`, `demultiplex.sh`, `denoise.sh`),
  `scripts/commands.txt` (reference commands), and an in-progress CWL port
  (`CWL/Tools/qiime2/import.cwl`, `scripts/wf.1.0.cwl`; `scripts/wf.1.2.cwl` empty).
- **QIIME 1 (legacy):** the OTU-based CWL workflows in `CWL/Workflows/qiime/` +
  `CWL/Tools/qiime/`, wrapping QIIME 1.9.1 scripts under `mgrast/qiime:1.0`.

The two do not share code; the Python driver is where active work happens.

## Known issues & recent fixes

Recently fixed (see git history on this branch):

- `run demux` now works (`demux_data` implemented; dispatch no longer passes a
  nonexistent `args.output_dir`).
- `--barcode-column-name` is now honored (was hardcoded to `BarcodeSequence`);
  its default is `BarcodeSequence`.
- `read_metadata_columns` trims whitespace and a leading `#`.
- `data-analysis-wf.sh` classifier name corrected `gg-18-8` → `gg-13-8`.

Open / tracked (see issue #5): remaining metadata-hardening items. When touching
these areas, update issue #5 and this section.
