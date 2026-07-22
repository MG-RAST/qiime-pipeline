# User Guide

How to run the pipeline end to end. For what the outputs mean see [PI.md](PI.md);
for the full tool/output reference see [PIPELINE.md](PIPELINE.md).

## Prerequisites

- A QIIME 2 environment on `PATH` (`conda activate scope-env` or a QIIME 2
  amplicon install). The native `qiime`, plus `wget` and `biom`, must be callable.
- Internet access for `setup` (downloads the classifier).
- Roomy scratch space — DADA2/demux write large temp files (see `--tmpdir`).

## 1. Prepare inputs

You need:

1. **Raw reads** — Illumina bcl2fastq "Undetermined" output, three files whose
   names contain `_R1_`, `_R2_`, and `_I1_`:
   `Undetermined_*_R1_*.fastq.gz` (forward), `_R2_` (reverse), `_I1_` (barcodes).
2. **A mapping file** — tab-delimited QIIME metadata whose name contains
   `mapping`. It must have a `#Sample ID` column and a barcode column named
   `BarcodeSequence` (12 bp Golay barcodes for EMP).

## 2. Stage the run (`setup`)

```bash
python scripts/qiime-console.py setup /path/to/raw_source /path/to/base_dir
```

This creates `base_dir/input/{raw_data,mapping.txt}`, renames the raw files to
`forward/reverse/barcodes.fastq.gz`, and downloads
`gg-13-8-99-515-806-nb-classifier.qza` into `input/`.

## 3. Run the workflow

```bash
python scripts/qiime-console.py run workflow /path/to/base_dir \
    --p-trunc-len-f 250 --p-trunc-len-r 250 \
    --p-sampling-depth 20000 \
    --beta-diversity-group-by Sample_Plate
```

The deliverable is built automatically at the end (see step 5).

### Key parameters (defaults are the CLI/argparse values)

| Flag | Default | Meaning |
|---|---|---|
| `--p-trunc-len-f` / `--p-trunc-len-r` | `0` | Truncate forward/reverse reads at this position (0 = no truncation). Set from the demux quality plots. |
| `--p-sampling-depth` | `20000` | Rarefaction depth for diversity. **⚠ Footgun:** every sample with fewer reads is dropped from diversity analysis. Do **not** accept the default blindly — pick it from the feature-table/demux summaries. |
| `--p-max-depth` | `10000` | Max depth for rarefaction curves. |
| `--p-steps` | `10` | Number of rarefaction steps. |
| `--beta-diversity-group-by` | none | Metadata column(s) for beta-group significance. Repeatable. Validated against the mapping header up front (typos fail fast). |
| `--barcode-column-name` | `BarcodeSequence` | Mapping column holding the barcodes. |
| `--p-n-threads` | `0` | DADA2 threads (0 = all cores). |
| `--tmpdir` | auto | Scratch dir for QIIME temp files. Precedence: `--tmpdir` > `$QIIME_TMPDIR` > `$TMPDIR` > `/scratch/tmp/qiime` > `<base_dir>/tmp`. Avoids small RAM-backed `/tmp`. |

## 4. Check quality

- **`output/demux/demux-full.qzv`** — per-sample read counts and quality; use it
  to choose truncation lengths and a sensible sampling depth.
- **`output/stats-dada2.qzv`** — how many reads survived filtering, merging, and
  chimera removal per sample.
- Open any `.qzv` by dragging it onto <https://view.qiime2.org>.

## 5. Package for sharing (automatic, or on demand)

`run workflow` already builds `output/deliverable/` and
`output/<run>-deliverable.tar.gz`. To (re)build it standalone:

```bash
python scripts/qiime-console.py package /path/to/base_dir --format both \
    --p-trunc-len-f 250 --p-trunc-len-r 250 --p-sampling-depth 20000 \
    --beta-diversity-group-by Sample_Plate
```

`--format` is `folder`, `tar`, or `both` (default). Any parameter flags you pass
are recorded in `MANIFEST.txt`. See [PIPELINE.md](PIPELINE.md#table-2--outputs)
for exactly what is included.

## Running individual steps (advanced)

The workflow can be driven a stage at a time against the same `base_dir`:

```bash
python scripts/qiime-console.py run demux   /path/to/base_dir   # import + demux + summarize
python scripts/qiime-console.py run denoise /path/to/base_dir   # dada2 denoise-paired
```

Normally you just run `run workflow`, which chains everything.
