# Documentation

Documentation for the QIIME 2 16S rRNA amplicon pipeline
([`scripts/qiime-console.py`](../scripts/qiime-console.py)).

## Which doc do I want?

| I am a… | Start here | You'll get |
|---|---|---|
| **PI / reviewer** | [PI.md](PI.md) | What the pipeline measures, how to read results, reproducibility & citations |
| **User** running it | [USER.md](USER.md) | Step-by-step: setup → run → QC → package, with all parameters |
| **Developer** changing it | [DEVELOPER.md](DEVELOPER.md) | Code architecture, stage functions, extension points, gotchas |
| **Maintainer** operating it | [MAINTAINER.md](MAINTAINER.md) | Environment, classifier, Docker, releases, roadmap |
| Anyone needing the details | [PIPELINE.md](PIPELINE.md) | Flow diagram + full tool/input and output tables (source of truth) |

## Presentation

- [slides/review.md](slides/review.md) — Marp deck for a review presentation.
  Pre-rendered alongside it: [review.html](slides/review.html),
  [review.pdf](slides/review.pdf), [review.pptx](slides/review.pptx).
  Regenerate with `marp docs/slides/review.md -o review.html` (or `--pdf` /
  `--pptx`) if `marp-cli` is installed; the source reads fine as Markdown too.

## Keeping docs honest

The tables in `PIPELINE.md` are hand-maintained and stamped with the commit they
describe. `scripts/check_docs_tables.py` asserts that every `qiime` step and every
deliverable entry in `qiime-console.py` appears in those tables — run it before
merging changes that touch the pipeline.

See also the agent-oriented [`CLAUDE.md`](../CLAUDE.md) at the repo root.
