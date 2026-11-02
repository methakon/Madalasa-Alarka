"""Keep the approved Figma baseline distinct from local extension proposals."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'backend/tests'))
from check_erd_references import validate


class LogicalModelVersionTests(unittest.TestCase):
    def setUp(self):
        self.v1=json.loads((ROOT/'docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json').read_text())
        self.proposal=json.loads((ROOT/'docs/data-model/MADALASA_ALARKA_LOGICAL_ERD_V2_LOCAL_PROPOSAL_2026-10-29.json').read_text())

    def test_canonical_baseline_and_unapproved_extension_remain_distinct(self):
        self.assertEqual(self.v1['tableCount'],120)
        self.assertEqual(self.proposal['tableCount'],124)
        self.assertEqual(validate(self.v1),[])
        self.assertEqual(validate(self.proposal),[])
        self.assertFalse(self.proposal['provenance']['live_figma_reverified'])
        names=lambda x:{t['name'] for d in x['domains'] for t in d['tables']}
        self.assertEqual(names(self.proposal)-names(self.v1),{'admin_sessions','child_pickup_viewer_passes','compliance_export_bundles','credential_renewal_challenges'})

    def test_bad_targets_and_duplicate_count_drift_fail(self):
        model=copy.deepcopy(self.v1)
        model['domains'][0]['tables'][0]['columns'].append('FK bad → definitely_missing_entity')
        self.assertTrue(any('definitely_missing_entity' in error for error in validate(model)))
        model['domains'][0]['tables'].append(copy.deepcopy(model['domains'][0]['tables'][0]))
        errors=validate(model)
        self.assertTrue(any('duplicate' in error for error in errors))
        self.assertTrue(any('tableCount' in error for error in errors))
