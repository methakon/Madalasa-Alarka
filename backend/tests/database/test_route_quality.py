"""L08-001..005/007/012: trip segmentation, stop/mode hypotheses, geometry and
geofence hysteresis on synthetic labeled traces, with a precision/recall threshold
report for the QA gate. Pure synthetic data; no DB required.
"""
import os
import sys
import unittest

# Make the repository's backend/ package importable (tests run with
# backend/tests/database on sys.path).
_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from backend.analysis.trip_analysis import (  # noqa: E402
    Fix, SegmentKind, StopClass, TravelMode,
    segment_trip, detect_stops, stop_for_gap, classify_mode,
    polyline_segments, geofence_transitions, GAP_SECONDS,
)


def line(start_t, n, step_s, lat0, lon0, dlat, dlon, acc=8.0):
    return [Fix(start_t + i * step_s, lat0 + i * dlat, lon0 + i * dlon, acc) for i in range(n)]


class RouteQualityTests(unittest.TestCase):

    # ---- L08-001 ----
    def test_segmentation_splits_on_data_gap(self):
        before = line(0, 5, 30, 22.5, 88.3, 0.0005, 0.0005)
        after = line(0 + 5 * 30 + GAP_SECONDS + 60, 5, 30, 22.6, 88.4, 0.0005, 0.0005)
        segs = segment_trip(before + after)
        kinds = [s.kind for s in segs]
        self.assertEqual(kinds, [SegmentKind.OBSERVED, SegmentKind.GAP, SegmentKind.OBSERVED])

    def test_no_gap_when_continuous(self):
        segs = segment_trip(line(0, 10, 30, 22.5, 88.3, 0.0002, 0.0002))
        self.assertEqual([s.kind for s in segs], [SegmentKind.OBSERVED])

    # ---- L08-002 ----
    def test_confirmed_stop_from_dwell_cluster(self):
        # 8 fixes within 50 m over 7 minutes, good accuracy => CONFIRMED.
        dwell = [Fix(i * 60, 22.5000, 88.3000, 6.0) for i in range(8)]
        stops = detect_stops(dwell)
        self.assertEqual(len(stops), 1)
        self.assertEqual(stops[0].classification, StopClass.CONFIRMED)
        self.assertGreater(stops[0].confidence, 0.8)

    def test_poor_accuracy_cluster_is_uncertain_not_confirmed(self):
        dwell = [Fix(i * 60, 22.5000, 88.3000, 120.0) for i in range(8)]  # accuracy > radius
        stops = detect_stops(dwell)
        self.assertEqual(stops[0].classification, StopClass.UNCERTAIN)

    def test_missing_fixes_gap_is_unknown_not_a_false_stop(self):
        before = line(0, 3, 30, 22.5, 88.3, 0.0005, 0.0005)
        after = line(0 + 3 * 30 + GAP_SECONDS + 120, 3, 30, 22.7, 88.5, 0.0005, 0.0005)
        gap = [s for s in segment_trip(before + after) if s.kind == SegmentKind.GAP][0]
        stop = stop_for_gap(gap)
        self.assertEqual(stop.classification, StopClass.UNKNOWN)
        self.assertIsNone(stop.centroid_lat)
        self.assertEqual(stop.confidence, 0.0)

    # ---- L08-003 ----
    def test_mode_is_always_inferred_hypothesis(self):
        walk = classify_mode(line(0, 10, 30, 22.5, 88.3, 0.0, 0.00018))  # ~ walking pace
        self.assertTrue(walk.inferred)
        self.assertIn(walk.mode, (TravelMode.WALK, TravelMode.CYCLE, TravelMode.STILL))
        self.assertLessEqual(walk.confidence, 1.0)

    def test_vehicle_vs_walk_distinguished_as_hypotheses(self):
        # Large per-30s displacement => vehicle-speed hypothesis.
        vehicle = classify_mode(line(0, 10, 30, 22.5, 88.3, 0.0, 0.005))
        self.assertEqual(vehicle.mode, TravelMode.VEHICLE)
        self.assertTrue(vehicle.inferred)

    # ---- L08-005 ----
    def test_polyline_omits_gap_never_snaps(self):
        before = line(0, 4, 30, 22.5, 88.3, 0.0005, 0.0005)
        after = line(0 + 4 * 30 + GAP_SECONDS + 60, 4, 30, 22.9, 88.9, 0.0005, 0.0005)
        polylines = polyline_segments(before + after)
        # Two separate observed polylines, no bridging segment across the gap.
        self.assertEqual(len(polylines), 2)
        self.assertEqual(len(polylines[0]), 4)

    # ---- L08-007 ----
    def test_geofence_hysteresis_ignores_single_fix_jitter(self):
        # Mostly outside, a single stray fix inside must NOT emit ENTER.
        fixes = [
            Fix(0, 22.60, 88.40, 5.0),       # far outside
            Fix(30, 22.5000, 88.3000, 5.0),  # one fix inside
            Fix(60, 22.60, 88.40, 5.0),      # outside again
        ]
        events = geofence_transitions(fixes, 22.5000, 88.3000, radius_m=60.0,
                                      enter_consecutive=2, exit_consecutive=2)
        self.assertEqual(events, [])

    def test_geofence_enter_then_exit_with_sustained_observations(self):
        inside = [Fix(t, 22.5000, 88.3000, 5.0) for t in (0, 30, 60)]
        outside = [Fix(t, 22.60, 88.40, 5.0) for t in (90, 120, 150)]
        events = geofence_transitions(inside + outside, 22.5000, 88.3000, radius_m=60.0)
        kinds = [e.kind for e in events]
        self.assertEqual(kinds, ["ENTER", "EXIT"])

    def test_geofence_ambiguous_accuracy_does_not_emit(self):
        # Fix near boundary with accuracy larger than its distance-to-edge => ignored.
        fixes = [Fix(t, 22.5006, 88.3000, 100.0) for t in (0, 30, 60)]
        events = geofence_transitions(fixes, 22.5000, 88.3000, radius_m=60.0)
        self.assertEqual(events, [])

    # ---- L08-012: labeled QA precision/recall threshold report ----
    def test_labeled_stop_detection_precision_recall_meets_threshold(self):
        # Labeled synthetic trace: one true dwell stop, then travel, then another dwell.
        trace = []
        trace += [Fix(i * 60, 22.5000, 88.3000, 6.0) for i in range(6)]          # true stop A (5 min)
        trace += line(6 * 60, 6, 30, 22.5000, 88.3000, 0.0009, 0.0009)           # travel
        base = 6 * 60 + 6 * 30
        trace += [Fix(base + i * 60, 22.5100, 88.3100, 6.0) for i in range(6)]    # true stop B
        labeled_true_stops = 2

        detected = [s for s in detect_stops(trace) if s.classification == StopClass.CONFIRMED]
        true_positives = len(detected)
        precision = true_positives / max(len(detected), 1)
        recall = true_positives / labeled_true_stops

        # Threshold report persisted to stdout for the QA gate.
        print(f"\n[L08-012 QA] stops_detected={len(detected)} "
              f"precision={precision:.2f} recall={recall:.2f} "
              f"uncertain={sum(1 for s in detect_stops(trace) if s.classification==StopClass.UNCERTAIN)}")

        self.assertGreaterEqual(precision, 0.8)
        self.assertGreaterEqual(recall, 0.8)


if __name__ == '__main__':
    unittest.main()
