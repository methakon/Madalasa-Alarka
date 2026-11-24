#!/usr/bin/env python3
"""L15-002 static contract: the free six-hour visibility window is an access
bound and stays independent of any storage/retention decision.

Acceptance: "Free endpoint cannot exceed 6h while storage gate remains distinct".

This is a source-level contract check, exactly like test_privacy_route_contract.py.
It does NOT replace the behavioural database test
(backend/tests/database/test_premium_history_leases.py), which proves against real
PostgreSQL that a paid household still cannot read beyond the window.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
READS = (ROOT / "src/free_location_reads.h").read_text()
MAIN = (ROOT / "src/main.cc").read_text()
RETENTION = (ROOT / "src/retention_policy.h").read_text()


class HistoryVisibilityContract(unittest.TestCase):
    def test_free_window_is_clamped_server_side_to_six_hours(self):
        # The window is a fixed SQL predicate anchored to server time, never a
        # value supplied by the caller.
        self.assertIn("interval '6 hours'", READS)
        self.assertIn("o.observed_at<=statement_timestamp()", READS)
        self.assertIn("history_window_hours", READS)
        self.assertIn('out["history_window_hours"]=6;', READS)

    def test_caller_cannot_widen_the_window(self):
        # No query parameters at all, and no client-supplied range is read.
        self.assertIn("free location reads do not accept query parameters", READS)
        self.assertNotIn("getParameter(", READS)
        self.assertNotIn("getOptionalParameter", READS)
        # The page size is a server constant, not client input.
        self.assertIn("const int pageLimit=history ? 200 : 1;", READS)

    def test_both_free_routes_use_the_same_clamped_reader(self):
        self.assertIn('"/v1/children/{childId}/location/latest"', MAIN)
        self.assertIn('"/v1/children/{childId}/location/history"', MAIN)
        self.assertIn("ma::free_location_read(std::move(req),std::move(childId),parent,false)", MAIN)
        self.assertIn("ma::free_location_read(std::move(req),std::move(childId),parent,true)", MAIN)

    def test_visibility_window_is_not_a_storage_schedule(self):
        # The read path must not carry retention, purge or deletion behaviour:
        # showing six hours may never be turned into a six-hour TTL.
        lowered = READS.lower()
        for forbidden in ("retention", "retain_for", "purge", "delete from", "ttl"):
            self.assertNotIn(forbidden, lowered,
                             f"read path must not implement storage {forbidden}")

    def test_storage_gate_remains_distinct_and_undecided(self):
        # The retention component still refuses to schedule anything until an
        # exact period is approved, so no category inherits the six-hour window.
        self.assertIn("enum class DecisionState { Undecided, Approved }", RETENTION)
        self.assertIn("scheduling_enabled{false}", RETENTION)
        self.assertIn("no positive approved period", RETENTION)
        self.assertIn("kFreeHistoryVisibilityHours = 6", RETENTION)


if __name__ == "__main__":
    unittest.main()
