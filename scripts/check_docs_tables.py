#!/usr/bin/env python3
"""Guard against drift between the pipeline code and the hand-written tables in
docs/PIPELINE.md.

Read-only. Parses scripts/qiime-console.py for:
  1. every `qiime <cmd> <subcmd>` invoked via subprocess.run, and
  2. every DELIVERABLE_FILES / DELIVERABLE_DIRS entry,
and asserts each appears somewhere in docs/PIPELINE.md.

Exit 0 if the docs cover everything, 1 (with a report) otherwise. Intended for
CI or a pre-merge check when touching the pipeline.
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, 'scripts', 'qiime-console.py')
DOC = os.path.join(REPO, 'docs', 'PIPELINE.md')


def read(path):
    with open(path) as f:
        return f.read()


def qiime_commands(src):
    """Return the set of 'cmd subcmd' strings from subprocess.run(['qiime', ...])."""
    cmds = set()
    for m in re.finditer(r"subprocess\.run\(\[\s*'qiime'\s*,\s*'([^']+)'\s*,\s*'([^']+)'", src):
        cmds.add('{} {}'.format(m.group(1), m.group(2)))
    return cmds


def _block(src, name):
    """Text of a `NAME = [ ... ]` list literal."""
    m = re.search(re.escape(name) + r"\s*=\s*\[(.*?)\]", src, re.DOTALL)
    return m.group(1) if m else ''


def deliverable_tokens(src):
    """Filenames/dirs referenced in DELIVERABLE_FILES / DELIVERABLE_DIRS."""
    tokens = set()
    files_block = _block(src, 'DELIVERABLE_FILES')
    for m in re.finditer(r"'([^']+)'", files_block):
        tok = m.group(1)
        if re.search(r'\.(qza|qzv|tsv|txt|biom)$', tok):
            tokens.add(os.path.basename(tok))
    dirs_block = _block(src, 'DELIVERABLE_DIRS')
    for m in re.finditer(r"'([^']+)'", dirs_block):
        tokens.add(m.group(1))
    return tokens


def main():
    if not os.path.exists(SRC) or not os.path.exists(DOC):
        print('ERROR: expected {} and {}'.format(SRC, DOC), file=sys.stderr)
        return 2
    src, doc = read(SRC), read(DOC)

    missing = []
    for cmd in sorted(qiime_commands(src)):
        if cmd not in doc:
            missing.append('qiime command not documented: {}'.format(cmd))
    for tok in sorted(deliverable_tokens(src)):
        if tok not in doc:
            missing.append('deliverable entry not documented: {}'.format(tok))

    if missing:
        print('docs/PIPELINE.md is out of sync with scripts/qiime-console.py:\n')
        for m in missing:
            print('  - ' + m)
        print('\nUpdate the tables in docs/PIPELINE.md, then re-run this check.')
        return 1

    print('OK: docs/PIPELINE.md covers all {} qiime commands and all deliverable '
          'entries.'.format(len(qiime_commands(src))))
    return 0


if __name__ == '__main__':
    sys.exit(main())
