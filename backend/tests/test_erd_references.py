import copy
import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from check_erd_references import validate

ERD = pathlib.Path(__file__).resolve().parents[2] / "docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json"

class ERDLinksTest(unittest.TestCase):
    def setUp(self):
        self.erd = json.loads(ERD.read_text())

    def test_current_erd(self):
        self.assertEqual(validate(self.erd), [])

    def test_bad_target_is_detected(self):
        e = copy.deepcopy(self.erd)
        e["domains"][0]["tables"][0]["columns"].append("FK x → missing_table")
        self.assertTrue(any("missing_table" in x for x in validate(e)))

    def test_duplicate_and_count_drift_detected(self):
        e = copy.deepcopy(self.erd)
        e["domains"][0]["tables"].append(copy.deepcopy(e["domains"][0]["tables"][0]))
        self.assertTrue(any("duplicate" in x for x in validate(e)))
        self.assertTrue(any("tableCount" in x for x in validate(e)))

if __name__ == "__main__":
    unittest.main()
