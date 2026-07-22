---
marp: true
theme: default
paginate: true
title: QIIME 2 16S Pipeline — Review
---

# QIIME 2 16S rRNA Pipeline
## Technical Review

Amplicon microbiome pipeline · `scripts/qiime-console.py`

<!-- Render: marp docs/slides/review.md -o review.html  (or .pdf) -->

---

## The problem

- Raw multiplexed Illumina 16S reads → **who is in each sample, and how do
  communities differ?**
- Needs to be **reproducible** (provenance, checksums) and **shareable** with
  collaborators who may re-analyze.
- Historically: scattered shell scripts + a legacy QIIME 1 CWL path, no single
  driver, no packaged deliverable.

---

## The goal

- One driver (`qiime-console.py`) from raw reads → taxonomy + diversity.
- EMP paired-end protocol, **DADA2 ASVs** (exact sequences, not 97% OTUs).
- A curated, checksummed **deliverable** bundle for hand-off.
- Documentation for PIs, users, developers, maintainers.

---

## Pipeline at a glance

```
setup → import → demux → dada2 denoise
      → phylogeny (+ taxonomy/classify/barplot)
      → diversity (core-metrics, alpha/beta significance, rarefaction)
      → relative abundance (collapse L1–7)
      → package (deliverable/ + .tar.gz + MANIFEST)
```

Full Mermaid diagram + tool/output tables: **[PIPELINE.md](../PIPELINE.md)**

⚠ Taxonomy runs *inside* `run_phylogeny_analysis`, **before** diversity.

---

## Inputs

- **Raw reads:** `Undetermined_*_{R1,R2,I1}_*.fastq.gz` (forward / reverse /
  barcode), staged and renamed by `setup`.
- **Mapping file:** tab-delimited QIIME metadata; `#Sample ID` + `BarcodeSequence`
  (12 bp Golay).
- **Classifier:** Greengenes 13-8 515F/806R naive-Bayes, fetched by `setup`
  (pinned to `sklearn-1.4.2`).

---

## Per-stage walkthrough

| Stage | Tool | Produces |
|---|---|---|
| Import | `tools import` | EMP paired-end artifact |
| Demux | `demux emp-paired` + summarize | per-sample reads + QC |
| Denoise | `dada2 denoise-paired` | ASV table, rep-seqs, stats |
| Phylogeny | `align-to-tree-mafft-fasttree` | rooted tree |
| Taxonomy | `classify-sklearn` + `taxa barplot` | taxonomy + bar plots |
| Diversity | `core-metrics-phylogenetic` + significance | alpha/beta + PCoA |
| Rel. abund. | `taxa collapse` L1–7 | rank tables |

---

## Outputs: exported vs internal

**Exported** (in the deliverable): ASV table, rep-seqs, denoising stats, rooted
tree, taxonomy, taxa bar plots, demux QC, `core-metrics-results/`,
`alpha-rarefaction-results/`, `metadata.tsv`, `MANIFEST.txt`.

**Internal** (working products, not shipped): `paired-end-demux.qza`, demux
artifacts, alignments, unrooted tree, `phyla-table.*` / `rel-phyla-table.*`.

Split matches `DELIVERABLE_FILES`/`DELIVERABLE_DIRS` in code.

---

## Packaging & provenance

- `package` builds `output/deliverable/` **and** `<run>-deliverable.tar.gz`.
- Includes `.qza` **data** artifacts (for downstream re-analysis) + `.qzv`
  viewers + metadata.
- **`MANIFEST.txt`**: md5 checksum + size per file, run params, QIIME version.
- **Per-artifact provenance**: every `.qza`/`.qzv` embeds its full action graph +
  citations → <https://view.qiime2.org> → Provenance tab.

---

## QC & interpretation

- **`demux-full.qzv`** → choose truncation lengths & sampling depth.
- **`stats-dada2.qzv`** → reads surviving filter/merge/chimera.
- ⚠ **`--p-sampling-depth` default 20000** drops any shallower sample — set it
  from the summaries, don't accept the default.
- Diversity + PERMANOVA answer *richness*, *evenness*, and *between-group*
  differences.

---

## Reproducibility

- Deterministic driver; parameters recorded in `MANIFEST.txt`.
- QIIME provenance travels **with** every artifact.
- Checksums verify bundle integrity on transfer.
- Docs stamped to a commit; `check_docs_tables.py` guards table/code drift.

---

## Known issues & roadmap

- **Fixed recently:** `run demux` works; `--barcode-column-name` honored; metadata
  headers trimmed; shell classifier name corrected.
- **Tracked:** remaining metadata hardening (issue #5).
- **Roadmap:** QIIME 2 CWL port (`wf.1.0.cwl`); retire legacy QIIME 1 CWL; Python
  driver as single source of truth.

---

## Summary

- End-to-end QIIME 2 ASV pipeline in one driver.
- Curated, checksummed, provenance-rich deliverable for collaborators.
- Documented for every audience; tables kept honest against the code.

**Docs:** `docs/` · **Reference:** [PIPELINE.md](../PIPELINE.md)
