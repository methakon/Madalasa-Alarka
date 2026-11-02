"""Documentation inventory checks only; not Android, legal or provider acceptance."""
from collections import Counter
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PHASES = ROOT / 'docs' / 'phases'
ANDROID = PHASES / 'M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md'
PLAY = PHASES / 'M9-play-release/01-play-and-data-safety'
BILLING = ROOT / 'docs/roadmap/PLAY_BILLING_SANDBOX_ACCESS_CHECKLIST_NO_SECRETS_2026-10-29.md'


def require_ids(text, pattern, expected):
    """Reject absent, duplicated and unexpected first-column IDs, not prose mentions."""
    found = re.findall(r'^\| (' + pattern + r') \|', text, re.MULTILINE)
    counts = Counter(found)
    missing = set(expected) - counts.keys()
    extra = counts.keys() - set(expected)
    duplicated = {key for key, count in counts.items() if count != 1}
    if missing or extra or duplicated:
        raise ValueError(f'inventory mismatch: missing={sorted(missing)}, '
                         f'extra={sorted(extra)}, duplicates={sorted(duplicated)}')
    return found


class PendingIdentityDocumentation(unittest.TestCase):
    def test_android_maps_every_srs_requirement(self):
        srs = (PHASES / 'M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md').read_text()
        expected = set(re.findall(r'\bFR-\d{3}\b', srs))
        self.assertTrue(expected)
        self.assertEqual(len(require_ids(ANDROID.read_text(), r'FR-\d{3}', expected)), len(expected))

    def test_android_supplemental_inventory_is_explicit(self):
        self.assertEqual(len(require_ids(ANDROID.read_text(), r'AND-\d{2}',
                                        {f'AND-{i:02}' for i in range(1, 41)})), 40)

    def test_android_each_inventory_row_has_all_nine_fields(self):
        rows = [line for line in ANDROID.read_text().splitlines()
                if re.match(r'^\| (FR-\d{3}|AND-\d{2}) \|', line)]
        for row in rows:
            with self.subTest(inventory_id=row.split('|')[1].strip()):
                cells = re.split(r'(?<!\\)\|', row)[1:-1]
                self.assertEqual(len(cells), 9)
                self.assertTrue(all(cell.strip() for cell in cells))

    def test_parent_and_child_have_separate_complete_checklists(self):
        text = (PLAY / 'PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md').read_text()
        for prefix in ('P', 'C'):
            with self.subTest(application=prefix):
                self.assertEqual(len(require_ids(text, prefix + r'\d{2}',
                                                {f'{prefix}{i:02}' for i in range(1, 21)})), 20)

    def test_data_safety_flow_inventory(self):
        self.assertEqual(len(require_ids((PLAY / 'DATA_SAFETY_WORKSHEET.md').read_text(),
                         r'DS\d{2} [^|]+', self._data_safety_labels())), 18)

    @staticmethod
    def _data_safety_labels():
        # Exact descriptions can evolve; the independently checked identifier set cannot silently disappear.
        text = (PLAY / 'DATA_SAFETY_WORKSHEET.md').read_text()
        labels = re.findall(r'^\| (DS\d{2} [^|]+) \|', text, re.MULTILINE)
        counts = Counter(label.split()[0] for label in labels)
        if counts != Counter({f'DS{i:02}': 1 for i in range(1, 19)}):
            raise ValueError('Data Safety category identifiers missing, duplicated or unexpected')
        return set(labels)

    def test_billing_cases_remain_unexecuted_preparation(self):
        text = BILLING.read_text()
        expected = {'INITIAL', 'PENDING', 'TOPUP', 'ACK', 'CAPACITY', 'FOUNDING', 'GRANTS',
                    'EXPIRY', 'REVERSAL', 'RESTORE', 'RTDN', 'VIEWER', 'PRICE-TAX'}
        self.assertEqual(len(require_ids(text, r'M7-BILL-[A-Z-]+',
                                        {'M7-BILL-' + item for item in expected})), 13)
        self.assertIn('Every row below is **NOT RUN', text)

    def test_missing_row_is_rejected_even_if_prose_mentions_it(self):
        with self.assertRaises(ValueError):
            require_ids('FR-002 is discussed in prose\n| FR-001 | value |\n', r'FR-\d{3}',
                        {'FR-001', 'FR-002'})

    def test_duplicate_and_unexpected_rows_are_rejected(self):
        for fixture in ('| P01 | value |\n| P01 | value |\n',
                        '| P01 | value |\n| P02 | value |\n'):
            with self.subTest(fixture=fixture), self.assertRaises(ValueError):
                require_ids(fixture, r'P\d{2}', {'P01'})


if __name__ == '__main__':
    unittest.main()
