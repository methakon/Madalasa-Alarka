#!/usr/bin/env python3
"""Validate document control, preservation, protected scope and local navigation."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from documentation import (check_links, destination_identity, destination_spans,
                           normalized_content, strip_control_header)

ROOT = Path(__file__).resolve().parents[2]
ROOT_DOCS_ALLOWLIST = {
    'README.md', 'LICENSE', 'MASTER_DOCUMENT_CONTROL_REGISTER.md',
    'document-control-register.json', 'DOCUMENT_RELOCATION_MANIFEST.json',
    'DOCUMENT_CONTROL_POLICY.md', 'DOCUMENTATION_PHASE_GATE_CHECKLIST.md',
    'PHASE_DOCUMENTATION_COVERAGE_MATRIX.md', 'openapi.yaml', 'openapi-m1.yaml',
}
RETAINED_LEGACY = {'docs/LICENSE'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git_bytes(ref, path):
    return subprocess.check_output(['git', 'show', f'{ref}:{path}'], cwd=ROOT)


def validate(check_source_git=False):
    errors = []
    manifest = json.loads((ROOT / 'docs/DOCUMENT_RELOCATION_MANIFEST.json').read_text())
    register = json.loads((ROOT / 'docs/document-control-register.json').read_text())
    baseline = json.loads((ROOT / 'docs/validation/reorganization-baseline.json').read_text())
    entries = manifest['entries']
    records = register['documents']
    mapping = {e['original_path']: e['canonical_path'] for e in entries}
    retired = {k: v for k, v in mapping.items() if k not in RETAINED_LEGACY}

    def require(ok, message):
        if not ok:
            errors.append(message)

    require(len(entries) == len(mapping) == len(set(mapping.values())) == 72,
            'Manifest must contain exactly 72 unique source and destination paths')
    require(len(records) == register['relocated_document_count'] == 72,
            'Machine register must contain exactly 72 relocated entries')
    require({r['canonical_path'] for r in records} == set(mapping.values()), 'Register and manifest path sets differ')
    require(len({r['document_id'] for r in records}) == 72, 'Duplicate catalogue IDs')
    record_map = {r['canonical_path']: r for r in records}
    preserved = 0
    original_bytes = 0
    for entry in entries:
        old, new = ROOT / entry['original_path'], ROOT / entry['canonical_path']
        record = record_map.get(entry['canonical_path'])
        require(new.is_file(), f'Missing canonical document: {new}')
        if not new.is_file() or not record:
            continue
        text = new.read_text()
        require(text.startswith('<!-- document-control:start -->\n') and
                text.count('<!-- document-control:end -->') == 1, f'Invalid control header: {new}')
        body = strip_control_header(text)
        require(body != text, f'Control header did not strip: {new}')
        expected = record['normalized_source_sha256']
        actual = digest(normalized_content(body).encode())
        require(actual == expected, f'Original substantive content changed/truncated: {new}')
        if actual == expected:
            preserved += 1
        require(entry['phase'] == record['phase'] and entry['category'] == record['category'],
                f'Phase/category mismatch: {new}')
        require(record['legacy_path'] == entry['original_path'], f'Legacy path mismatch: {new}')
        for field in ['version_or_baseline', 'proposed_owner_role', 'proposed_reviewer_role',
                      'status', 'content_approval_status', 'implementation_evidence_status',
                      'open_blockers', 'last_reviewed_date', 'approval_evidence']:
            require(bool(record.get(field)), f'Missing register field {field}: {new}')
        require(record['status'] in register['status_vocabulary'], f'Unknown lifecycle stage: {new}')
        if record['status'] == 'APPROVED':
            require(record['approval_evidence'] not in {'TBD', 'NOT_RECORDED', ''}, f'Unevidenced approval: {new}')
        if entry['original_path'] in RETAINED_LEGACY:
            require(entry.get('compatibility_pointer') == 'RETAINED' and old.is_file(),
                    f'Retained root pointer missing or mislabelled: {old}')
            if old.is_file():
                pointer = old.read_text()
                require(len(pointer) < 1200, f'Retained pointer is not lightweight: {old}')
                destinations = [pointer[a:b] for a, b in destination_spans(pointer)]
                require(any((old.parent / dest.split('#')[0]).resolve() == new.resolve()
                            for dest in destinations),
                        f'Retained pointer does not link to exact canonical path: {old}')
        else:
            require(entry.get('compatibility_pointer') == 'RETIRED_2026-10-27',
                    f'Pointer status not recorded as retired: {old}')
            require(not old.exists(), f'Retired root path still exists: {old}')
        require('not operative' in text.lower() or 'non-operative' in text.lower() or new.name != 'LICENSE',
                'Candidate licence must remain explicitly non-operative')
        original_bytes += record['source_bytes']
        if check_source_git:
            source = git_bytes(manifest['source_commit'], entry['original_path'])
            blob_sha = subprocess.check_output(['git', 'hash-object', '--stdin'], input=source, cwd=ROOT).decode().strip()
            require(blob_sha == entry['source_blob_sha'] == record['source_blob_sha'], f'Source Git blob mismatch: {old}')
            require(len(source) == record['source_bytes'], f'Source byte count mismatch: {old}')
            require(digest(normalized_content(source.decode()).encode()) == expected,
                    f'Source baseline digest mismatch: {old}')
            def identity(url, doc_path):
                value = destination_identity(url, doc_path, {})
                if isinstance(value, str):
                    return ('EXTERNAL', value, '', '')
                return (mapping.get(value[0], value[0]), value[1], value[2])

            register_link = identity('../../../MASTER_DOCUMENT_CONTROL_REGISTER.md',
                                     entry['canonical_path'])
            before = sorted(identity(source.decode()[a:b], entry['original_path'])
                            for a, b in destination_spans(source.decode()))
            after = sorted(identity(body[a:b], entry['canonical_path'])
                           for a, b in destination_spans(body))
            # The control header adds exactly one link; nothing else may change.
            if register_link in after:
                after.remove(register_link)
            require(before == after, f'Link target meaning/query/fragment changed: {new}')

    canonical = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'docs/phases').rglob('*')
                 if p.is_file() and p.name != 'README.md'}
    require(canonical == set(mapping.values()), 'Missing/extra/duplicate full canonical copy in docs/phases')
    stray = sorted(p.name for p in (ROOT / 'docs').iterdir()
                   if p.is_file() and p.name not in ROOT_DOCS_ALLOWLIST)
    require(not stray, f'Unexpected file(s) at docs root: {stray}')
    protected = baseline['protected_files']
    navigation = baseline.get('navigation_reference_updates', {})
    for name, sha in protected.items():
        p = ROOT / name
        require(p.is_file(), f'Protected artifact removed: {name}')
        if not p.is_file():
            continue
        current = digest(p.read_bytes())
        update = navigation.get(name)
        if current != sha:
            require(update is not None, f'Protected artifact changed: {name}')
            if update is None:
                continue
            require(update['baseline_sha256'] == sha, f'Stale navigation baseline record: {name}')
            require(current == update['current_sha256'], f'Unrecorded edit to {name}')
            body = normalized_content(p.read_text())
            if update.get('whitespace_normalization'):
                body = re.sub(r'[ \t]+(?=\n)', '', body)
            for pair in update.get('text_reference_updates', []):
                require(body.count(pair['to']) == 1,
                        f'Recorded text-path update is stale for {name}')
                body = body.replace(pair['to'], pair['from'])
            require(digest(body.encode()) == update['normalized_sha256'],
                    f'Edit to {name} changed more than link destinations')
        if check_source_git and update is None:
            require(digest(git_bytes(baseline['completion_base_commit'], name)) == sha,
                    f'Protected baseline not authentic: {name}')
    for name, reason in baseline.get('supporting_path_updates', {}).items():
        require((ROOT / name).is_file(), f'Supporting path file removed: {name}')
        require(bool(reason), f'Supporting path update recorded without reason: {name}')
    for name, update in baseline.get('policy_code_updates', {}).items():
        p = ROOT / name
        require(p.is_file() and digest(p.read_bytes()) == update['current_sha256'],
                f'Policy code file drifted from its recorded revision: {name}')
        require(bool(update.get('reason')), f'Policy code change recorded without reason: {name}')
        if check_source_git:
            require(digest(git_bytes(baseline['completion_base_commit'], name)) ==
                    update['baseline_sha256'], f'Policy code baseline not authentic: {name}')

    support = register['unmoved_artifacts']
    require(len(support) == register['unmoved_artifact_count'] == 5, 'Expected two APIs and three UI index entries')
    for record in support:
        path = ROOT / record['canonical_path']
        require(path.is_file() and digest(path.read_bytes()) == record['sha256'],
                f'Unmoved API/UI artifact changed: {path}')
        require(record['content_approval_status'] != 'APPROVED', 'Unsupported artifact approval')

    files = [p for p in ROOT.rglob('*') if p.is_file() and not any(
        part in {'.git', '.venv', '__pycache__', 'node_modules', 'build'} for part in p.relative_to(ROOT).parts)
        and (p.suffix.lower() in {'.md', '.html'} or p.name == 'LICENSE')]
    links = check_links(ROOT, files, {})
    known = []
    remaining = list(links['errors'])
    exceptions = json.loads((ROOT / 'docs/validation/link-exceptions.json').read_text())['exceptions']
    for exception in exceptions:
        matches = [e for e in remaining if e.startswith(exception['kind'] + ': ' + exception['source'] + ':')
                   and e.endswith(' -> ' + exception['target'])]
        # An exception must be narrow, active and confined to an unchanged protected file.
        require(len(matches) == 1, f'Link exception stale or ambiguous: {exception}')
        require(exception['source'] in protected, 'Link exception is not for a protected baseline file')
        for match in matches:
            remaining.remove(match)
            known.append({'error': match, 'reason': exception['reason'], 'status': exception['status']})
    errors.extend(remaining)
    retired_links = []
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text()
        for a, b in destination_spans(text):
            target = destination_identity(text[a:b], rel, {})[0]
            if target in retired:
                retired_links.append(f'{rel} -> {target}')
    require(not retired_links, f'Links still point at retired root stubs: {retired_links[:5]}')

    table = (ROOT / 'docs/MASTER_DOCUMENT_CONTROL_REGISTER.md').read_text()
    require(sum(line.startswith('| DOC-') for line in table.splitlines()) == 72, 'Human register does not have 72 source rows')
    require((ROOT / 'docs/DOCUMENTATION_PHASE_GATE_CHECKLIST.md').is_file(), 'Missing phase gate checklist')
    require(not any(r['phase'] == 'M5' for r in records), 'Do not invent an M5 standalone source document')
    counts = Counter(e['phase'] for e in entries)
    counts['M5'] = 0
    categories = Counter(f"{e['phase']}/{e['category']}" for e in entries)
    return {
        'source_baseline_commit': manifest['source_commit'],
        'completion_base_commit': baseline['completion_base_commit'],
        'canonical_document_count': len(entries),
        'retired_legacy_pointer_count': len(retired),
        'retained_legacy_pointer_count': len(RETAINED_LEGACY),
        'docs_root_file_count': len(ROOT_DOCS_ALLOWLIST),
        'navigation_reference_update_count': len(navigation),
        'preserved_document_count': preserved, 'original_source_bytes': original_bytes,
        'phase_counts': dict(counts), 'category_counts': dict(categories),
        'phase_index_count': len(manifest['phase_dirs']), 'category_index_count': len(categories),
        'protected_artifact_count': len(protected), 'unmoved_register_entries': len(support),
        'source_git_verification': check_source_git,
        'link_files_checked': links['files_checked'], 'local_links_checked': links['local_links_checked'],
        'local_anchors_checked': links['anchors_checked'],
        'known_preexisting_link_issues': known, 'errors': errors,
        'external_urls': 'Preserved byte-for-byte in source bodies; not fetched or availability-tested',
        'readiness': 'Documentation validation only; no content/legal/implementation/pilot/release approvals',
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check-source-git', action='store_true', help='Independently verify source and protected Git baseline blobs (full history required)')
    ap.add_argument('--report', type=Path, help='Write a JSON report; does not modify documents')
    args = ap.parse_args()
    result = validate(args.check_source_git)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(f"Documents: {result['canonical_document_count']} canonical in phase folders; "
          f"{result['retired_legacy_pointer_count']} retired root stubs absent; "
          f"{result['retained_legacy_pointer_count']} retained root pointer; "
          f"{result['preserved_document_count']} source bodies preserved")
    print(f"docs/ root control files: {result['docs_root_file_count']}; phases/categories: {result['phase_index_count']}/{result['category_index_count']}")
    print(f"Protected artifacts: {result['protected_artifact_count']} ({result['navigation_reference_update_count']} navigation-only link updates recorded)")
    print(f"Links: {result['local_links_checked']} across {result['link_files_checked']} files; anchors: {result['local_anchors_checked']}")
    for issue in result['known_preexisting_link_issues']:
        print('KNOWN UNRESOLVED: ' + issue['error'])
    for error in result['errors']:
        print('ERROR: ' + error, file=sys.stderr)
    print(f"Unexpected errors: {len(result['errors'])}; known protected-scope issues: {len(result['known_preexisting_link_issues'])}")
    return 1 if result['errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
