"""Offline API/storage boundary contract; no database or build invocation."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PairingIssuerContract(unittest.TestCase):
    def test_api_uses_guarded_issuer_without_identity_arguments(self):
        src = (ROOT / 'backend/src/pairing.h').read_text()
        self.assertNotIn('INSERT INTO ap_m1.pairing_codes', src)
        self.assertIn('ap_m1.issue_device_pairing_code($1::uuid, $2::bytea, $3::integer)', src)
        self.assertIn('*normalized_child, code_hex, requested_ttl', src)
        self.assertLess(src.index('has_child_scope_v2'), src.index('idempotency_claim'))
        self.assertLess(src.index('outcome == "REPLAY"'), src.index('generate_pairing_code()'))
        self.assertIn('original code cannot be recovered', src)
        self.assertIn('std::string("{}")', src)
        self.assertIn('requested_ttl < 60 || requested_ttl > 600', src)

    def test_storage_boundary_locks_then_revalidates_and_keeps_runtime_read_only(self):
        src = (ROOT / 'backend/persistence/migrations/0030_guarded_device_pairing_code_issuer.sql').read_text()
        self.assertIn('child uuid, code_hash bytea, ttl integer', src)
        self.assertIn('RETURNS timestamptz', src)
        self.assertIn('SECURITY DEFINER SET search_path=pg_catalog,ap_m1', src)
        self.assertIn('OWNER TO ap_db_executor', src)
        self.assertIn('FROM PUBLIC,ap_m1_auth,ap_auth_issuer,ap_m1_owner', src)
        self.assertIn('TO ap_m1_api', src)
        self.assertNotIn('TO ap_m1_api;', src.split('GRANT INSERT')[1].split('CREATE FUNCTION')[0])
        lock = src.index('FOR UPDATE')
        for guard in ['ap_m1.ctx_principal()', 'ap_m1.ctx_device()', "'PAIR_DEVICE'", 'ap_m1.child_free_admitted(child)', "s.expires_at>clock_timestamp()"]:
            self.assertIn(guard, src[lock:src.index('INSERT INTO')])
        self.assertIn("d.enrollment_state='ACTIVE'", src)
        self.assertIn('p.consumed_at IS NULL AND p.expires_at>clock_timestamp()', src)
        self.assertIn('ttl NOT BETWEEN 60 AND 600', src)
        self.assertIn('octet_length(code_hash)<>32', src)
        self.assertIn("ERRCODE='23505'", src)


if __name__ == '__main__':
    unittest.main()
