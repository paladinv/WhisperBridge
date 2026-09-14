#!/usr/bin/env python3
"""Validate QA records, not the unimplemented transcription app."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', action='store_true')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--results', default='qa/results.json')
    args = parser.parse_args()
    result_path = (ROOT / args.results).resolve()
    if ROOT not in result_path.parents:
        parser.error('Results must be inside this workspace')
    cases = json.loads((ROOT / 'qa/cases.json').read_text())
    results = json.loads(result_path.read_text())
    errors = []
    ids = [c['id'] for c in cases]
    rids = [r['id'] for r in results]
    if len(ids) != len(set(ids)) or len(rids) != len(set(rids)):
        errors.append('Duplicate case/result IDs')
    if set(ids) != set(rids):
        errors.append('Result IDs must match case IDs exactly')
    defined = set(re.findall(r'^## (UC-\d+):', (ROOT / 'docs/USE_CASES.md').read_text(), re.M))
    if {c['use_case'] for c in cases} != defined:
        errors.append('Use-case coverage is incomplete or contains unknown IDs')
    if {c['requirement'] for c in cases} != {f'R{i:02}' for i in range(1, 13)}:
        errors.append('Requirement coverage must include R01 through R12')
    rendered = (ROOT / 'qa/CASES.md').read_text()
    for c in cases:
        if not all(c.get(k) for k in ('title', 'preconditions', 'steps', 'expected', 'evidence')):
            errors.append(f"{c['id']}: incomplete test definition")
        if c['priority'] not in ('P0', 'P1') or c['scope'] not in ('baseline', 'native', 'future'):
            errors.append(f"{c['id']}: invalid priority/scope")
        if f"## {c['id']} — {c['title']}" not in rendered:
            errors.append(f"{c['id']}: missing human-readable case")
    by_id = {r['id']: r for r in results}
    for r in results:
        if r['status'] not in ('NOT_RUN', 'BLOCKED', 'PASS', 'FAIL'):
            errors.append(f"{r['id']}: invalid status")
        if r['status'] != 'NOT_RUN' and not all(r.get(k) for k in ('actual', 'tester', 'environment')):
            errors.append(f"{r['id']}: executed/blocked result lacks context")
        if r['status'] == 'PASS' and not r.get('evidence'):
            errors.append(f"{r['id']}: PASS requires evidence")
        for item in r.get('evidence', []):
            path = (ROOT / item).resolve()
            if Path(item).is_absolute() or ROOT not in path.parents or not path.is_file():
                errors.append(f"{r['id']}: evidence must name an existing workspace-relative file")
    gated = [c for c in cases if c['scope'] == 'baseline' or (args.native and c['scope'] == 'native')]
    pending = [c['id'] for c in gated if by_id.get(c['id'], {}).get('status') != 'PASS']
    for error in errors:
        print('ERROR:', error)
    if errors:
        return 1
    print(f'QA kit valid: {len(cases)} cases, {len(defined)} use cases, 12 requirements.')
    print(f'Product results: {sum(r["status"] == "PASS" for r in results)} passed; {len(pending)} selected release cases have not passed.')
    if args.release and pending:
        print('RELEASE BLOCKED: ' + ', '.join(pending))
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
