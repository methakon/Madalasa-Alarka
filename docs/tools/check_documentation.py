#!/usr/bin/env python3
"""Current manifest/register and offline navigation checks; not release approval.

Adapted from historical check_reorganization.py at
09689396ac87cc427e9de51b0e6adc1a2dc85e4c. No obsolete source-body freeze,
72-header requirement, API hash freeze or link-error waiver is applied.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
from documentation import check_links, normalized_content

ROOT = Path(__file__).resolve().parents[2]
REGISTER = 'docs/document-control-register.json'
MANIFEST = 'docs/DOCUMENT_RELOCATION_MANIFEST.json'
HUMAN = 'docs/MASTER_DOCUMENT_CONTROL_REGISTER.md'


def human_records(root):
    rows = []
    for line in (root / HUMAN).read_text().splitlines():
        if not line.startswith('| DOC-'):
            continue
        cells = [c.strip() for c in line.split('|')[1:-1]]
        match = re.fullmatch(r'\[[^\]]+\]\(([^)]+)\)', cells[3])
        if not match:
            raise ValueError('Invalid canonical link in human register: ' + line)
        rows.append({'document_id': cells[0], 'phase': cells[1],
                     'human_category': cells[2], 'canonical_path': 'docs/' + match[1],
                     'proposed_owner_role': cells[4], 'status': cells[5]})
    return rows


def derive_register(root):
    manifest = json.loads((root / MANIFEST).read_text())
    entries = {e['canonical_path']: e for e in manifest['entries']}
    records = human_records(root)
    for row in records:
        entry = entries[row['canonical_path']]
        row.update(category=entry['category'], legacy_path=entry['original_path'],
                   owner_assignment=entry['owner_assignment'],
                   approval_evidence=entry['approver_signature'],
                   content_approval_status='NOT_CERTIFIED_BY_DOCUMENTATION_CHECK',
                   implementation_evidence_status='NOT_CERTIFIED_BY_DOCUMENTATION_CHECK')
    return {'schema_version': 2, 'scope': 'Relocation catalogue only; not all project documentation',
            'authorities': [HUMAN, MANIFEST], 'document_count': len(records),
            'approval_rule': 'Mirror recorded states only; never infer approval from existence or passing checks.',
            'documents': records}


def input_paths(root):
    """Every tracked Markdown/HTML/LICENSE plus nonignored new inputs."""
    names = subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root
    ).decode().split('\0')
    return sorted({root / n for n in names if n and (Path(n).suffix.lower() in {'.md', '.html'}
                  or Path(n).name == 'LICENSE') and (root / n).is_file()})


def preservation_errors(before, after, plain_updates=(), allow_list_break=False):
    """Prove navigation-only edits; explicit inverse path substitutions for plain text."""
    for old, new in plain_updates:
        if before.count(old) != after.count(new):
            return ['Plain navigation substitution count mismatch']
        after = after.replace(new, old)
    if allow_list_break:
        after = after.replace('\n- ', '\\n- ')
        before = before.replace('\n- ', '\\n- ')
    return [] if normalized_content(before) == normalized_content(after) else ['Protected substantive body changed/truncated']


def validate(root=None, paths=None):
    root = (root or ROOT).resolve()
    errors = []
    manifest = json.loads((root / MANIFEST).read_text())
    actual = json.loads((root / REGISTER).read_text())
    expected = derive_register(root)
    entries = manifest['entries']
    canonical = [e['canonical_path'] for e in entries]
    ids = [e['registry_id'] for e in entries]
    if len(canonical) != manifest['document_count'] or len(set(canonical)) != len(canonical):
        errors.append('Manifest count/duplicate path mismatch')
    if len(set(ids)) != len(ids):
        errors.append('Duplicate manifest catalogue ID')
    if len(actual.get('documents', [])) != len(canonical):
        errors.append('Register scope/count mismatch')
    if actual != expected:
        errors.append('Machine register differs from current human register/manifest; unevidenced approval or stale scope')
    if Counter(r['canonical_path'] for r in expected['documents']) != Counter(canonical):
        errors.append('Human register/manifest path scope mismatch')
    for row in expected['documents']:
        e = next((e for e in entries if e['canonical_path'] == row['canonical_path']), None)
        if e and (row['document_id'] != e['registry_id'] or row['phase'] != e['phase'] or row['status'] != e['review_status']):
            errors.append('Human register/manifest metadata mismatch: ' + row['canonical_path'])
        if not (root / row['canonical_path']).is_file():
            errors.append('Missing canonical document: ' + row['canonical_path'])
        if row['status'] == 'APPROVED' and row['approval_evidence'] in {'NOT_RECORDED', '', 'TBD'}:
            errors.append('Unevidenced approval: ' + row['canonical_path'])
    # These real navigation references are not Markdown destinations. Keep the
    # ownership patterns, operative licence pointer and issue-template URL current.
    for name in ['LICENSE', '.github/CODEOWNERS', '.github/ISSUE_TEMPLATE/config.yml']:
        p = root / name
        if not p.is_file():
            errors.append('Missing navigation control: ' + name)
            continue
        text = p.read_text()
        for entry in entries:
            if entry['original_path'] in text:
                errors.append('Retired plain navigation reference: ' + name + ' -> ' + entry['original_path'])
    links = check_links(root, paths if paths is not None else input_paths(root), {})
    errors.extend(links['errors'])
    if not (root / 'docs/DOCUMENTATION_PHASE_GATE_CHECKLIST.md').is_file():
        errors.append('Missing phase gate checklist')
    return {'canonical_document_count': len(canonical), 'scope': actual['scope'],
            'link_files_checked': links['files_checked'], 'local_links_checked': links['local_links_checked'],
            'anchors_checked': links['anchors_checked'], 'errors': errors,
            'readiness': 'Documentation checks only; legal, implementation, device and release approval NOT conferred'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--report', type=Path)
    args = ap.parse_args()
    result = validate()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return int(bool(result['errors']))


if __name__ == '__main__':
    raise SystemExit(main())
