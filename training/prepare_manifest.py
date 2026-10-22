from __future__ import annotations
import argparse
import csv
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent


def parse_sources(text: str):
    rows = []
    current = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('- id: '):
            if current: rows.append(current); current = {}
            current['id'] = line[6:].strip()
        elif line.startswith('hf: '): current['hf'] = line[4:].strip()
        elif line.startswith('task: '): current['task'] = line[6:].strip()
        elif line.startswith('license: '): current['license'] = line[9:].strip()
    if current: rows.append(current)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='kofi_training_manifest.csv')
    args = ap.parse_args()
    rows = parse_sources((ROOT / 'sources.yaml').read_text(encoding='utf-8'))
    with (ROOT / args.out).open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['id','hf','task','license'])
        writer.writeheader(); writer.writerows(rows)
    print(f'Wrote {len(rows)} source records to {ROOT / args.out}')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
