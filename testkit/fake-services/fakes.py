#!/usr/bin/env python3
"""L01-013 deterministic offline fakes: clock, OIDC, Play, FCM.

No network, no live provider calls, no real secrets. Used to run time- and
provider-dependent tests offline. LOCAL only.

Self-test: python3 testkit/fake-services/fakes.py --selftest
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field


class FakeClock:
    """Controllable virtual clock (epoch seconds)."""

    def __init__(self, start: int = 1_767_225_600):  # 2026-01-01T00:00:00Z
        self._now = int(start)

    def now(self) -> int:
        return self._now

    def advance(self, seconds: int) -> int:
        self._now += int(seconds)
        return self._now

    def set(self, epoch: int) -> None:
        self._now = int(epoch)


class FakeOidcVerifier:
    """Verifies only synthetic tokens; returns a synthetic stable sub.

    Never contacts Google. Identity only - asserts NO parent-child relationship.
    """

    PREFIX = "synthetic-oidc:"

    def verify(self, token: str) -> dict | None:
        if not isinstance(token, str) or not token.startswith(self.PREFIX):
            return None  # fail closed on anything non-synthetic
        sub = token[len(self.PREFIX):].strip()
        if not sub:
            return None
        return {"iss": "https://fake.local", "aud": "madalasa-local",
                "sub": f"demo_{sub}", "relationship_claim": None}


@dataclass
class FakePlayProvider:
    """Synthetic purchases/entitlements; no real charge or purchase token."""

    _entitlements: dict = field(default_factory=dict)

    def purchase(self, child_id: str, sku: str) -> dict:
        token = f"synthetic-play-token:{child_id}:{sku}"  # not a real token
        self._entitlements[(child_id, sku)] = token
        return {"child_id": child_id, "sku": sku, "synthetic_token": token, "charged": False}

    def is_entitled(self, child_id: str, sku: str) -> bool:
        return (child_id, sku) in self._entitlements


@dataclass
class FakeFcmSender:
    """Records pushes in-memory. Delivery != receipt, != capture."""

    sent: list = field(default_factory=list)

    def send(self, device_id: str, payload: dict) -> dict:
        self.sent.append((device_id, dict(payload)))
        return {"queued": True, "delivered_proof": False}


def _selftest() -> int:
    ok = True

    clk = FakeClock()
    t0 = clk.now()
    clk.advance(48 * 3600)
    ok &= clk.now() - t0 == 48 * 3600  # 48h trial window math

    oidc = FakeOidcVerifier()
    ok &= oidc.verify("synthetic-oidc:parentA") == {
        "iss": "https://fake.local", "aud": "madalasa-local",
        "sub": "demo_parentA", "relationship_claim": None}
    ok &= oidc.verify("real-google-token") is None      # fail closed
    ok &= oidc.verify("") is None

    play = FakePlayProvider()
    rec = play.purchase("demo_child_01", "prepaid_month")
    ok &= rec["charged"] is False and play.is_entitled("demo_child_01", "prepaid_month")
    ok &= not play.is_entitled("demo_child_02", "prepaid_month")

    fcm = FakeFcmSender()
    res = fcm.send("demo_device_01", {"type": "alert"})
    ok &= res["delivered_proof"] is False and len(fcm.sent) == 1

    print("fake-services self-test:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        raise SystemExit(_selftest())
    print("fake-services loaded; run with --selftest")
