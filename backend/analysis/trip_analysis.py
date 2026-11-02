"""Synthetic, deterministic trip/stop/mode/geofence analysis candidates.

These are LABELED HYPOTHESES with confidence, never invented certainty. They operate
on synthetic observation traces so Phase-08 acceptance (precision/recall on labeled
datasets, no false exact stop when fixes missing, walk/ride labeled inferred, no fake
road segments across gaps, geofence hysteresis without jitter spam) can be measured.

This does NOT replace the observed-only DB persistence (ap_m1.publish_observed_trip);
it is the candidate-generation/QA layer the roadmap places under backend/src/trips and
backend/src/places, implemented in the project's tested-Python idiom.

Pure Python, no external deps, no real data.
"""
from dataclasses import dataclass, field
from enum import Enum
from math import radians, sin, cos, asin, sqrt
from typing import Optional


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6_371_000.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    return 2 * r * asin(sqrt(a))


@dataclass(frozen=True)
class Fix:
    """A synthetic GPS observation."""
    t: float            # observed epoch seconds
    lat: float
    lon: float
    accuracy_m: float


class SegmentKind(str, Enum):
    OBSERVED = "OBSERVED"
    GAP = "GAP"          # missing data span — never road-snapped


class StopClass(str, Enum):
    CONFIRMED = "CONFIRMED"
    UNCERTAIN = "UNCERTAIN"   # accuracy too poor / dwell ambiguous
    UNKNOWN = "UNKNOWN"       # insufficient fixes to assert a stop


class TravelMode(str, Enum):
    STILL = "STILL"
    WALK = "WALK"
    CYCLE = "CYCLE"
    VEHICLE = "VEHICLE"
    UNKNOWN = "UNKNOWN"


@dataclass
class Segment:
    kind: SegmentKind
    start_t: float
    end_t: float
    fixes: list = field(default_factory=list)


@dataclass
class Stop:
    classification: StopClass
    start_t: float
    end_t: Optional[float]
    centroid_lat: Optional[float]
    centroid_lon: Optional[float]
    dwell_seconds: float
    confidence: float          # 0..1, never asserted as certainty


@dataclass
class ModeHypothesis:
    mode: TravelMode
    confidence: float
    inferred: bool = True      # always a hypothesis, never ground truth


# ---- L08-001: event-time trip segmentation (split on long gaps) ----

GAP_SECONDS = 300.0  # >5 min with no fix => data gap, matches DB routepoint rule


def segment_trip(fixes: list) -> list:
    """Split a time-ordered fix list into OBSERVED segments separated by GAP spans."""
    ordered = sorted(fixes, key=lambda f: f.t)
    segments: list = []
    current: list = []
    for i, fx in enumerate(ordered):
        if current and fx.t - current[-1].t > GAP_SECONDS:
            segments.append(Segment(SegmentKind.OBSERVED, current[0].t, current[-1].t, list(current)))
            segments.append(Segment(SegmentKind.GAP, current[-1].t, fx.t, []))
            current = []
        current.append(fx)
    if current:
        segments.append(Segment(SegmentKind.OBSERVED, current[0].t, current[-1].t, list(current)))
    return segments


# ---- L08-002: stop detection with confidence and UNKNOWN gaps ----

STOP_RADIUS_M = 50.0
MIN_DWELL_SECONDS = 180.0  # ~3 min minimum meaningful dwell


def detect_stops(fixes: list) -> list:
    """Detect dwell clusters. A cluster with poor accuracy is UNCERTAIN; a span with
    too few fixes to assert dwell is UNKNOWN (never a false exact stop)."""
    ordered = sorted(fixes, key=lambda f: f.t)
    stops: list = []
    i = 0
    n = len(ordered)
    while i < n:
        anchor = ordered[i]
        j = i + 1
        members = [anchor]
        while j < n and haversine_m(anchor.lat, anchor.lon, ordered[j].lat, ordered[j].lon) <= STOP_RADIUS_M:
            members.append(ordered[j])
            j += 1
        dwell = members[-1].t - members[0].t
        if dwell >= MIN_DWELL_SECONDS and len(members) >= 2:
            worst_acc = max(m.accuracy_m for m in members)
            # If accuracy radius exceeds the stop radius, the stop is UNCERTAIN.
            cls = StopClass.UNCERTAIN if worst_acc > STOP_RADIUS_M else StopClass.CONFIRMED
            clat = sum(m.lat for m in members) / len(members)
            clon = sum(m.lon for m in members) / len(members)
            conf = 0.9 if cls == StopClass.CONFIRMED else 0.5
            stops.append(Stop(cls, members[0].t, members[-1].t, clat, clon, dwell, conf))
            i = j
        else:
            i += 1
    return stops


def stop_for_gap(gap: Segment) -> Stop:
    """A data gap yields an UNKNOWN stop with no centroid — never a confirmed visit."""
    return Stop(StopClass.UNKNOWN, gap.start_t, gap.end_t, None, None,
                gap.end_t - gap.start_t, confidence=0.0)


# ---- L08-003: motion kind hypothesis with confidence ----

def classify_mode(fixes: list) -> ModeHypothesis:
    """Guess travel mode from median speed. Always inferred, never asserted."""
    ordered = sorted(fixes, key=lambda f: f.t)
    if len(ordered) < 2:
        return ModeHypothesis(TravelMode.UNKNOWN, 0.0, inferred=True)
    speeds = []
    for a, b in zip(ordered, ordered[1:]):
        dt = b.t - a.t
        if dt <= 0:
            continue
        speeds.append(haversine_m(a.lat, a.lon, b.lat, b.lon) / dt)
    if not speeds:
        return ModeHypothesis(TravelMode.UNKNOWN, 0.0, inferred=True)
    speeds.sort()
    median = speeds[len(speeds) // 2]
    if median < 0.3:
        return ModeHypothesis(TravelMode.STILL, 0.6, inferred=True)
    if median < 2.2:
        return ModeHypothesis(TravelMode.WALK, 0.7, inferred=True)
    if median < 6.0:
        return ModeHypothesis(TravelMode.CYCLE, 0.6, inferred=True)
    return ModeHypothesis(TravelMode.VEHICLE, 0.7, inferred=True)


# ---- L08-005: route geometry (observed polyline, gaps never bridged) ----

def polyline_segments(fixes: list) -> list:
    """Return only OBSERVED segments as (lat,lon) polylines; GAP spans are omitted
    (never filled with an invented road-snapped line)."""
    out = []
    for seg in segment_trip(fixes):
        if seg.kind == SegmentKind.OBSERVED:
            out.append([(f.lat, f.lon) for f in seg.fixes])
    return out


# ---- L08-007: geofence enter/exit with hysteresis and dedupe ----

class GeofenceState(str, Enum):
    OUTSIDE = "OUTSIDE"
    INSIDE = "INSIDE"


@dataclass
class GeofenceEvent:
    kind: str  # "ENTER" or "EXIT"
    t: float


def geofence_transitions(
    fixes: list,
    place_lat: float,
    place_lon: float,
    radius_m: float,
    enter_consecutive: int = 2,
    exit_consecutive: int = 2,
) -> list:
    """Emit ENTER/EXIT only after N consecutive confident observations inside/outside,
    so boundary jitter does not spam, and consecutive same-kind events are deduped."""
    ordered = sorted(fixes, key=lambda f: f.t)
    state = GeofenceState.OUTSIDE
    inside_run = 0
    outside_run = 0
    events: list = []
    for fx in ordered:
        dist = haversine_m(place_lat, place_lon, fx.lat, fx.lon)
        # Accuracy guard: ambiguous fixes (could be either side) don't advance a run.
        ambiguous = abs(dist - radius_m) < fx.accuracy_m
        inside = dist <= radius_m
        if ambiguous:
            inside_run = 0
            outside_run = 0
            continue
        if inside:
            inside_run += 1
            outside_run = 0
            if state == GeofenceState.OUTSIDE and inside_run >= enter_consecutive:
                events.append(GeofenceEvent("ENTER", fx.t))
                state = GeofenceState.INSIDE
        else:
            outside_run += 1
            inside_run = 0
            if state == GeofenceState.INSIDE and outside_run >= exit_consecutive:
                events.append(GeofenceEvent("EXIT", fx.t))
                state = GeofenceState.OUTSIDE
    return events
