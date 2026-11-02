"""Synthetic regression tests for document relocation and local link checking."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

MODULE = Path(__file__).with_name("documentation.py")


class DocumentationTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE.is_file(), "documentation validation implementation is missing")
        spec = importlib.util.spec_from_file_location("documentation", MODULE)
        assert spec is not None and spec.loader is not None
        self.doc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.doc)

    def urls(self, text):
        return [text[a:b] for a, b in self.doc.destination_spans(text)]

    def test_inline_image_and_balanced_destination(self):
        text = '[one](a(b).md "title") ![image](<a b.png>)'
        self.assertEqual(self.urls(text), ["a(b).md", "a b.png"])

    def test_reference_definition(self):
        text = '[one][ref]\n\n[ref]: ../SRS.md#scope "A title"\n'
        self.assertEqual(self.urls(text), ["../SRS.md#scope"])

    def test_fences_and_inline_code_are_untouched(self):
        text = '```sql\n[not](example.md)\n```\n`[no](other.md)` [yes](real.md)\n'
        self.assertEqual(self.urls(text), ["real.md"])

    def test_indented_code_is_untouched(self):
        self.assertEqual(self.urls('    [no](code.md)\n\n[yes](real.md)\n'), ["real.md"])

    def test_html_links_and_images(self):
        self.assertEqual(self.urls('<a href="guide.md#part">a</a> <img src="image.png">'),
                         ["guide.md#part", "image.png"])

    def test_autolinks_are_not_rewritten(self):
        self.assertEqual(self.urls('<https://example.com/path>\n'), [])

    def test_external_and_code_bytes_survive_rewrite(self):
        source = '[x](SRS.md) [web](https://example.com/a(b))\n```sh\ncat docs/SRS.md\n```\n'
        got = self.doc.rewrite_links(source, lambda url: 'new/' + url)
        self.assertEqual(got, '[x](new/SRS.md) [web](https://example.com/a(b))\n```sh\ncat docs/SRS.md\n```\n')

    def test_normalization_preserves_every_non_destination_byte(self):
        a = '# Title\n[x](old.md)\n```\nkeep this\n```\n'
        b = '# Title\n[x](../new.md)\n```\nkeep this\n```\n'
        self.assertEqual(self.doc.normalized_content(a), self.doc.normalized_content(b))
        self.assertNotEqual(self.doc.normalized_content(a), self.doc.normalized_content(b.replace('keep this', 'lost')))

    def test_control_header_roundtrip(self):
        body = '# Title\n\nOriginal **content**.\n'
        header = '<!-- document-control:start -->\n> Status: DOCUMENTED\n<!-- document-control:end -->\n\n'
        self.assertEqual(self.doc.strip_control_header(header + body), body)

    def test_anchors_gfm_duplicates_and_explicit_html(self):
        text = '# Hello, World!\n## Hello, World!\n<a id="custom"></a>\n'
        self.assertEqual(self.doc.anchors(text), {'hello-world', 'hello-world-1', 'custom'})

    def test_anchor_code_and_unicode(self):
        self.assertIn('31-api--সংকেত', self.doc.anchors('## 3.1 API / সংকেত\n'))
        self.assertNotIn('fake', self.doc.anchors('```\n# Fake\n```\n'))

    def test_detect_missing_local_target_and_anchor(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'target.md').write_text('# Existing\n')
            p = root / 'a.md'
            p.write_text('[ok](target.md#existing) [bad](target.md#missing) [gone](absent.md)')
            result = self.doc.check_links(root, [p], {})
            self.assertEqual(len(result['errors']), 2)
            self.assertTrue(any('missing anchor' in e for e in result['errors']))
            self.assertTrue(any('missing file' in e for e in result['errors']))

    def test_detect_reference_shortcut_and_collapsed_links(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root / 'a.md'
            p.write_text('[shortcut] [collapsed][]\n\n[shortcut]: gone.md\n[collapsed]: missing.md\n')
            self.assertEqual(len(self.doc.check_links(root, [p], {})['errors']), 2)

    def test_reject_repository_escape(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root / 'a.md'
            p.write_text('[escape](../../outside.md)')
            self.assertTrue(any('outside repository' in e for e in self.doc.check_links(root, [p], {})['errors']))

    def test_local_destination_identity_survives_relocation(self):
        self.assertTrue(hasattr(self.doc, 'destination_identity'), 'destination identity check is missing')
        mapping = {'docs/SRS.md': 'docs/phases/M1/design/SRS.md'}
        self.assertEqual(
            self.doc.destination_identity('SRS.md#scope', 'docs/a.md', mapping),
            self.doc.destination_identity('../../M1/design/SRS.md#scope', 'docs/phases/M2/ingest/a.md', mapping))
        self.assertNotEqual(
            self.doc.destination_identity('SRS.md#scope', 'docs/a.md', mapping),
            self.doc.destination_identity('../../M1/design/SRS.md#other', 'docs/phases/M2/ingest/a.md', mapping))

    def test_repository_validation_entry_point_exists(self):
        validator = MODULE.with_name('check_documentation.py')
        self.assertTrue(validator.is_file(), 'complete reorganization validator is missing')

    def test_legacy_target_is_reported_separately(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'old.md').write_text('[new](new.md)')
            (root / 'new.md').write_text('# Canonical\n')
            p = root / 'a.md'
            p.write_text('[old](old.md)')
            result = self.doc.check_links(root, [p], {'old.md': 'new.md'})
            self.assertEqual(len(result['legacy_redirects']), 1)


class CurrentDocumentationNegativeControls(unittest.TestCase):
    """Current controls, not obsolete 72-body/header or protected API freezes."""
    @classmethod
    def setUpClass(cls):
        import sys
        import json
        import shutil
        sys.path.insert(0, str(MODULE.parent))
        import check_documentation
        cls.validator = check_documentation
        root = MODULE.parents[2]
        # Fresh checkouts do not contain the ignored local scratch directory.
        (root / '.dev-environment').mkdir(exist_ok=True)
        cls.temp = tempfile.TemporaryDirectory(prefix='docs-check-', dir=root / '.dev-environment')
        cls.fixture = Path(cls.temp.name)
        # Exact tracked fixtures include JSON/API/source link targets. Never copy
        # untracked private environments, credentials or the project-local venv.
        import subprocess
        tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
        sources = {root / name for name in tracked if name and Path(name).name != '.env'}
        sources.update(cls.validator.input_paths(root))
        for p in sources:
            if not p.is_file():
                continue
            target = cls.fixture / p.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
        for name in [cls.validator.REGISTER, cls.validator.MANIFEST]:
            target = cls.fixture / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / name, target)
        cls.paths = [p for p in cls.fixture.rglob('*') if p.is_file() and
                     (p.suffix.lower() in {'.md', '.html'} or p.name == 'LICENSE')]
        errors = cls.validator.validate(cls.fixture, cls.paths)['errors']
        if errors:
            raise AssertionError(f'Initial current fixture must be valid: {errors}')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_truncated_canonical_body_fails(self):
        p = self.fixture / 'docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md'
        before = p.read_text()
        self.assertTrue(self.validator.preservation_errors(before, before[:-100]))
        self.assertFalse(self.validator.preservation_errors('[x](old.md)', '[x](new.md)'))

    def test_register_missing_duplicate_unexpected_rows_fail(self):
        # The current manifest retains legacy-root-links; do not demand historical
        # retirement of those valid compatibility pages. Detect scope corruption.
        import json
        p = self.fixture / self.validator.REGISTER
        before = p.read_text()
        try:
            for mutation in ('missing', 'duplicate', 'unexpected'):
                data = json.loads(before)
                if mutation == 'missing':
                    data['documents'].pop()
                else:
                    row = dict(data['documents'][0])
                    if mutation == 'unexpected':
                        row['canonical_path'] = 'docs/not-in-current-manifest.md'
                    data['documents'].append(row)
                p.write_text(json.dumps(data))
                self.assertTrue(self.validator.validate(self.fixture, self.paths)['errors'], mutation)
        finally:
            p.write_text(before)

    def test_link_to_retired_root_path_fails(self):
        p = self.fixture / 'README.md'
        before = p.read_text()
        try:
            p.write_text(before + '\n[old](docs/SRS.md)\n')
            self.assertTrue(any('missing file' in e for e in
                            self.validator.validate(self.fixture, self.paths)['errors']))
        finally:
            p.write_text(before)

    def test_contract_change_fails(self):
        before = '# Security contract\nDeny unverified access.\n[x](old.md)\n'
        after = before.replace('Deny', 'Allow')
        self.assertTrue(self.validator.preservation_errors(before, after))
        self.assertTrue(self.validator.preservation_errors(before, before + '\n'))

    def test_fabricated_approval_fails(self):
        import json
        p = self.fixture / self.validator.REGISTER
        before = p.read_text()
        try:
            data = json.loads(before)
            data['documents'][0]['status'] = 'APPROVED'
            p.write_text(json.dumps(data))
            self.assertTrue(any('unevidenced approval' in e for e in
                            self.validator.validate(self.fixture, self.paths)['errors']))
        finally:
            p.write_text(before)


if __name__ == '__main__':
    unittest.main()
