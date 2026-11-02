# M1 device credential lifecycle (engineering decisions C-01 to C-06)

Status: **synthetic engineering implementation and database/contract tests; not legal retention approval or production acceptance.**
The backend currently implements health and family creation, not these device HTTP flows. No Android application is implemented.
Retention values below remain engineering settings, subject to the separate legal/owner release gates.

Files: `docs/openapi-m1.yaml`, immutable historical migrations `0002_m1_device_credentials.sql` and `0003_m1_enrollment_and_credential_hardening.sql`, additive `0006_m1_concurrency_and_retention_holds.sql`,
tests `backend/tests/m1_credential_lifecycle.sql` (CL_01–CL_32) and `backend/tests/m1_enrollment.sql` (EN_01–EN_20),
acceptance cases T-M1-03, T-M1-04, T-M1-05, T-M1-11.

## Design
1. **Credential**: short-lived opaque bearer token; only its SHA-256 is stored; table ceiling 24 h.
2. **One live credential per device.** Renewing or enrolling revokes the previous one.
3. **Enrollment** (`redeem_pairing_code`, `consume_enrollment_challenge`, `activate_enrolled_device`): the code works once;
   the device is created `PENDING_PROOF`; on a valid key proof it becomes `ACTIVE`, its key is recorded and the **first
   credential is issued in the same transaction**.
4. **Renewal** needs proof of key possession, never the old token: challenge (`issue_credential_renewal_challenge`), then
   signature over a string beginning `amar-pola-m1-device-renew-v1`, so an enrollment signature cannot be replayed.
5. **Revocation** is immediate: token validity is joined to device and key state.
6. **Refusals never say why** (no device-existence oracle). Device HTTP rate limits below remain required backend work, not implemented behavior claimed by these SQL helpers.

### Two-step pattern (fixes the "commit after NULL" hazard from 0002)
```
tx1  consume_*()  -> challenge is spent, returns nonce hash + public key       COMMIT
     backend (no DB transaction open): compare nonce, verify ECDSA signature
tx2  issue_*() / activate_*()  -> only if tx1 was < 60 s ago, once
```
A failed proof means the backend simply never calls tx2, and the challenge is already spent and committed. A rollback of
tx2 fails closed and can be retried within 60 s. Tests: CL_19–CL_22, EN_07–EN_08, EN_14. The only way to reintroduce the
old hazard is to hold one database transaction open across the signature check, so **the backend must not**.

## Decisions
| # | Decision | Value | Why / how to change |
|---|----------|-------|---------------------|
| C-01 | Credential lifetime | **1 hour** (3600 s). Database bounds 5 min to 24 h. | Renew when under 20 min remain or on a 401. At most about one renewal an hour while the app is talking to the server, so battery cost is negligible. Shorter limits damage from a stolen token; longer saves little. Backend config only, no migration. |
| C-02 | Rate limits (enforced at proxy/backend, not in SQL) | `POST /enrollment` 10/min/IP. Challenge: 10/min/IP, 20/hour/device. Renew: 10/min/IP, 10/hour/device. Over limit: 429 with `Retry-After`, no row written. | Starting values to be tested in T-M1-11. The database already caps open challenges at 5 per device and pairing-code attempts at 20 per code. |
| C-03 | `device_proof_required` | **Removed from `DeviceToken`.** M1 uses a bearer token with proof of key possession only at enrollment and renewal. Per-request signing is out of M1. | The field was `const true` but nothing defined it, which invites an implementation that does not match the contract. Revisit per-request signing only if a threat model requires it (it costs a Keystore signature on every call). |
| C-04 | First credential at enrollment | **Done** in migration 0003 (`activate_enrolled_device`), covered by EN_10–EN_13. | |
| C-05 | Cleanup and retention | SQL cleanup and least-privilege `ma_purge` runner exist; nothing is deployed or scheduled. Engineering defaults: credentials 30 days after the earlier expiry/revocation; renewal challenges 1 day; expired enrollment artifacts, including completed ACTIVE/REVOKED enrollment, 7 days; old abandoned pending devices only without FK blockers. Floors 1 day / 1 hour / 1 day. Pairing purge requires an explicit grace of at least 1 day. | Hashes linked to device/child/family identifiers are not automatically anonymous. Approved legal holds prevent cleanup. These engineering settings do not establish lawful retention; no legal policy is changed or approved here. |
| C-06 | Key rotation | **Not in M1.** A lost or invalidated key means revoke the device and pair again with a new code. | Android Keystore keys without user-authentication binding do not normally expire. Rotation needs two-key proof and a new contract operation; add it when a real case appears. |

## Remaining work (needs the backend or a device)
- Backend implementation of the two-step calls, the hash of tokens and nonces before they reach SQL, and the ECDSA check.
- Schedule the purge job.
- Real-device check of Keystore signing and of the canonical signed string (T-M1-04 on hardware).
- Not designed: per-request signing, key rotation (see C-03, C-06).

## Additive 0006 concurrency and hold semantics

Renewal issuance, challenge issuance, consumption and enrollment activation serialize on the device before locking keys/challenges/credentials. At most five live unconsumed challenges are permitted; distinct consumed challenges cannot leave two unrevoked credentials. Validity and issuance timestamps use `clock_timestamp()` after lock waits, including the last credential-row wait. The two-transaction proof-verification boundary above remains unchanged.

`retention_hold` on devices, credentials, renewal/enrollment challenges and pairing codes prevents deletion without extending validity, restoring authentication or preventing revocation. A device hold preserves its device-bound artifacts too. A held artifact preserves its device through FK guards. A pairing hold preserves only that code: the historical schema has no redeemed-device relationship to infer. Runtime API/purge logins cannot mutate hold columns. Trusted maintenance must use device-first/target-row locking, verify that its target still exists, and retain its separately approved hold evidence; the boolean is not a legal-case provenance or multi-case management system.

Cleanup never removes audit events, device-key history or revocation epochs to make a device deletable. Idempotency retention is separate and has no hold extension in this slice. Tests: `m1_credential_concurrency.py` (barrier-driven two-session/burst/expiry/revocation cases) and `m1_retention_holds.sql` (fresh empty dedicated synthetic database, exact lifecycle/hold/ACL/FK counts).
