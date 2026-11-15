"""Synthetic PostgreSQL regression: one active Alarka per child, pairing audit.

Uses the dedicated loopback test DB only (fixture enforces this), and rolls back.
No IMEI, serial number, real family data or physical device identifier.
"""
import unittest
from uuid import uuid4
import psycopg
try:
    from . import fixtures
except ImportError:
    import fixtures


class SingleActiveChildDeviceTests(unittest.TestCase):
    def make_fixture(self, db):
        fam, child = uuid4(), uuid4()
        db.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'synthetic QR fixture')",(fam,))
        db.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'Synthetic child')",(child,fam))
        return fam,child

    def test_two_active_device_rows_for_one_child_fail_even_across_paths(self):
        db=fixtures.admin_connection()
        try:
            fam,child=self.make_fixture(db)
            db.execute(
                "INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,enrollment_state)"
                " VALUES(%s,%s,%s,'ACTIVE')",
                (fam,child,b'NOT-A-REAL-KEY-A'*12))
            # DB unique index is the non-bypassable concurrency guard.
            with self.assertRaises(psycopg.errors.UniqueViolation):
                with db.transaction():
                    db.execute(
                        "INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,enrollment_state)"
                        " VALUES(%s,%s,%s,'ACTIVE')",
                        (fam,child,b'NOT-A-REAL-KEY-B'*12))
        finally:
            db.rollback()
            db.close()

    def test_server_marked_activation_creates_log_and_revocation_closes_it(self):
        db=fixtures.admin_connection()
        try:
            fam,child=self.make_fixture(db)
            device=uuid4()
            db.execute(
                "INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,"
                "enrollment_state,pairing_method,reported_manufacturer,reported_model,"
                "reported_android_api,reported_app_version)"
                " VALUES(%s,%s,%s,%s,'PENDING_PROOF','PARENT_CODE','SyntheticCo',"
                "'TestPhone',35,'0.1')",
                (device,fam,child,b'NOT-A-REAL-KEY-X'*12))
            self.assertEqual(0,db.execute(
                "SELECT count(*) FROM ap_m1.child_device_pairing_log WHERE device_id=%s",
                (device,)).fetchone()[0])
            # The normal live route performs cryptographic proof BEFORE this
            # transition. Privileged synthetic fixture only tests audit trigger.
            db.execute("UPDATE ap_m1.devices SET enrollment_state='ACTIVE' WHERE id=%s",(device,))
            log=db.execute(
                "SELECT pairing_method,reported_model,reported_android_api,unpaired_at "
                "FROM ap_m1.child_device_pairing_log WHERE device_id=%s",(device,)).fetchone()
            self.assertEqual(('PARENT_CODE','TestPhone',35,None),log)
            db.execute(
                "UPDATE ap_m1.devices SET revoked_at=clock_timestamp(),"
                "enrollment_state='REVOKED' WHERE id=%s",(device,))
            self.assertIsNotNone(db.execute(
                "SELECT unpaired_at FROM ap_m1.child_device_pairing_log WHERE device_id=%s",
                (device,)).fetchone()[0])
            self.assertFalse(db.execute(
                "SELECT ap_m1.child_has_live_alarka_device(%s)",(child,)).fetchone()[0])
        finally:
            db.rollback()
            db.close()

    def test_child_erasure_removes_pairing_metadata(self):
        db=fixtures.admin_connection()
        try:
            fam,child=self.make_fixture(db)
            device=uuid4()
            db.execute(
                "INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,"
                "enrollment_state) VALUES(%s,%s,%s,%s,'PENDING_PROOF')",
                (device,fam,child,b'NOT-A-REAL-KEY-ERASE'*12))
            db.execute("UPDATE ap_m1.devices SET enrollment_state='ACTIVE' WHERE id=%s",(device,))
            self.assertEqual(1,db.execute(
                "SELECT count(*) FROM ap_m1.child_device_pairing_log WHERE child_id=%s",
                (child,)).fetchone()[0])
            db.execute("INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code)"
                       " VALUES(%s,'SYNTHETIC_ERASURE')",(child,))
            self.assertEqual(0,db.execute(
                "SELECT count(*) FROM ap_m1.child_device_pairing_log WHERE child_id=%s",
                (child,)).fetchone()[0])
        finally:
            db.rollback()
            db.close()
