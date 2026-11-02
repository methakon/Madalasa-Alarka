"""Live rollback-only negative controls for the cross-lineage equivalence checker."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'tools/database'))
from verify_lineages import application_shape
from fixtures import admin_connection


class EquivalenceNegativeControls(unittest.TestCase):
    def changed(self, statement):
        with admin_connection() as conn:
            before=application_shape(conn)
            try:
                conn.execute(statement)
                after=application_shape(conn)
                self.assertTrue(before!=after,'equivalence checker ignored: '+statement)
            finally:
                conn.rollback()

    def test_policy_definition_change_is_detected(self):
        self.changed('CREATE POLICY reconciliation_probe ON ap_m1.children FOR SELECT TO ap_m1_api USING(false)')

    def test_column_privilege_change_is_detected(self):
        self.changed('GRANT UPDATE(alias) ON ap_m1.children TO ap_m1_api')

    def test_runtime_role_membership_change_is_detected(self):
        self.changed('GRANT ap_service_worker TO ap_m1_api')

    def test_recovery_policy_change_is_detected(self):
        self.changed('CREATE POLICY reconciliation_probe ON ma_recovery.control FOR SELECT TO ap_m1_api USING(false)')
