# For Principal Investigators

A non-operational overview: what this pipeline measures, how to read the
results, and why they are reproducible. For the full technical reference see
[PIPELINE.md](PIPELINE.md).

## What it does, scientifically

The pipeline profiles the bacterial/archaeal community in each sample by
sequencing the 16S rRNA gene (V4 region, 515F/806R primers). It uses the
**Earth Microbiome Project** protocol and **QIIME 2**. Raw sequencing reads are
denoised into **amplicon sequence variants (ASVs)** — exact sequences, finer
resolution than traditional 97% OTUs — using DADA2, then classified against the
Greengenes reference and summarized with standard diversity metrics.

## What each result answers

| Result | Question it answers | Where to find it |
|---|---|---|
| Taxa bar plots (`taxa-bar-plots.qzv`) | *Who is present, and at what relative abundance, per sample/group?* | Deliverable |
| Alpha diversity (`core-metrics-results/`) | *How rich/even is each sample?* (Shannon, Faith PD, evenness, observed features) | Deliverable |
| Alpha-group significance | *Does within-sample diversity differ between metadata groups?* | `core-metrics-results/` |
| Beta diversity + PCoA/Emperor | *How different are whole communities between samples/groups?* (Bray-Curtis, Jaccard, UniFrac) | `core-metrics-results/` |
| Beta-group significance (PERMANOVA) | *Are between-group community differences statistically significant?* | `core-metrics-results/` |
| Rarefaction curves (`alpha-rarefaction-results/`) | *Did we sequence deeply enough to capture the diversity?* | Deliverable |
| Feature table + rep-seqs (`table-dada2`, `rep-seqs-dada2`) | *The raw ASV counts and sequences for any downstream re-analysis.* | Deliverable |

## What you receive

The shared bundle (`deliverable/` and a `.tar.gz`) contains the interpretable
results **and** the underlying data artifacts, so collaborators can do their own
downstream analysis: the ASV table, representative sequences, rooted tree,
taxonomy, taxa bar plots, diversity results, denoising/QC summaries, the sample
metadata, and a checksummed `MANIFEST.txt`. Intermediate working files are left
out to keep the bundle small.

## Reproducibility & provenance

- **Every result file carries its own provenance.** QIIME 2 `.qza`/`.qzv` files
  embed the complete chain of actions, parameters, and software versions used to
  produce them. Open any `.qzv` at <https://view.qiime2.org> → **Provenance** tab.
- **Citations are embedded too** (`citations.bib` inside each artifact) — the
  correct references for QIIME 2, DADA2, MAFFT/FastTree, UniFrac, and the
  Greengenes classifier for a methods section.
- **Bundle integrity** is recorded in `MANIFEST.txt` (md5 checksum + size per
  file, plus run parameters and QIIME version).

## Key methods to cite

QIIME 2 (Bolyen et al. 2019); DADA2 (Callahan et al. 2016); Greengenes 13-8
reference; MAFFT + FastTree for phylogeny; UniFrac for phylogenetic beta
diversity. Exact versions are in each artifact's provenance.
