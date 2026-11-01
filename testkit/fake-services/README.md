# testkit/fake-services (L01-013)

Deterministic, offline fakes for local tests: no network, no live Google
Identity/FCM/Play/maps calls, no real secrets. These let time-dependent and
provider-dependent logic run fully offline.

Components (`fakes.py`):

- `FakeClock` — controllable virtual clock (advance/set); used for 48h trial and
  100-day add-on expiry tests without real waiting.
- `FakeOidcVerifier` — returns a synthetic verified `sub` for a synthetic token;
  rejects anything else. Never contacts Google. Never asserts a parent-child
  relationship (that stays a separate legal gate).
- `FakePlayProvider` — synthetic purchase/entitlement; no real charge or token.
- `FakeFcmSender` — records pushes in-memory; delivering a push is not proof of
  receipt or of any capture.

Run the self-test: `python3 testkit/fake-services/fakes.py --selftest`.
