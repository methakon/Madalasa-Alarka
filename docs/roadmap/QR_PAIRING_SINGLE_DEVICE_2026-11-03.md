# Free-first Alarka pairing — child-generated QR and one active device per child

**Owner design decision 2026-11-03.** This supersedes the six-digit synthetic and parent-visible 10-character code as the **preferred user experience**, not the existing cryptographic enrollment backend. QR end-to-end is **design/integration work in progress**; do not display an unbound QR or claim pairing complete based on scan.

## Parent–child workflow

1. **Child installs free Alarka:** setup, transparency, privacy and device compatibility screens work without parent pairing. Monitoring, sensor collection and upload are OFF.
2. **Child requests a short-lived QR invitation:** Alarka creates an Android Keystore P-256 public key and contacts HTTPS `POST /v1/pairing/qr-sessions` (future endpoint) for a random opaque session ID, server nonce and short expiry (max 2–3 minutes). Server persists a hash of the invitation secret, public key fingerprint and initial session status `AWAITING_GUARDIAN`. Require rate limits, replay protection, expiry and abuse throttling.
3. **Child displays QR, parent scans with Madalasa:** QR encodes **version, temporary session ID, one-time invitation secret, public-key fingerprint and expiry only**. It contains no child alias, personal ID, location, IMEI, phone number, serial number, advertising ID or long-term bearer. Show manufacturer/model/Android version in the Alarka UI, and transmit the bounded fields over TLS as *untrusted informational metadata*. QR is never a monitoring grant.
4. **Parent signs in and selects an ADMITTED child:** Madalasa invokes Google Code Scanner (Google Play services) for QR capture *without requesting app camera permission* on supported Android devices; offer manual 10-character code as fallback for incompatible scanners/phones. The parent confirms the child profile, scanned device fingerprint and model. Backend validates verified session, exact child `PAIR_DEVICE` grant, current free admission, single-device exclusivity, valid unused QR session and pending enrollment identity.
5. **Server binds and child proves key possession:** new authenticated `POST /v1/children/{childId}/qr-pairing-claims` atomically binds the invitation to the child; child polls for an approved challenge, signs the nonce with AndroidKeyStore private key, and the server verifies the signature before transitioning the **same** device to ACTIVE. Reuse existing `/v1/enrollment` challenge/proof and device credential machinery where possible; QR is a *transport for an approved pairing intent*, not an alternate way around proof of possession.
6. **Audit after successful proof:** Write `ap_m1.child_device_pairing_log` with scoped child ID, family ID, pseudonymous device UUID, key fingerprint hash, enrollment timestamp, `QR_APPROVED`, Android API level, app version, manufacturer and model. Pairing is not monitoring: obtain separate current guardian consents, Android permissions, Play/legal eligibility and visible monitoring notification before any location starts.
7. **Subsequent scans:** if child already has an ACTIVE Alarka device, reject with `409 DEVICE_ALREADY_PAIRED`; show device model and pair date to authorized parents. Do not silently swap or attach a second active device. A parent-verified **Replace child device** procedure first revokes the previous credential/key and cancels pending commands or connections, records the historical unpair timestamp and only then authorizes a new invitation. Device/offline failure alone never frees a 108 child-service slot.
8. **Privacy:** a child-erasure tombstone also removes device pairing metadata; operational/audit retention and separately required legal holds must be explicitly reviewed. Never use model/manufacturer as a secret or hardware serial as a uniqueness key.

## Database/API implementation state

On `api` PR #28, new migration `v2:0024` adds:
- `ux_one_active_alarka_per_child`: unique partial index on `ap_m1.devices(child_id)` for `enrollment_state='ACTIVE' AND revoked_at IS NULL`. It is the authoritative race-safe device uniqueness fence and blocks a second ACTIVE row even from another handler.
- `ap_m1.child_device_pairing_log`: proof-transition audit with model/manufacturer/API/version/key fingerprint hash; historical revocation timestamp; deletes on erasure tombstone.
- `ap_m1.store_pending_device_profile(...)`: accepts validated informational metadata only inside an enrollment transaction, not as device authentication.
- `GET /v1/children/{childId}/paired-device`: exact-child, consent-safe scoped summary for the approved guardian (no raw key or token).
- Existing 10-character parent-code pairing endpoint now refuses issuing new codes for a child that already has an active device. Existing REST enrollment accepts optional `device_info` from Alarka; the proof-verified activation persists the audit.

**Not yet implemented or claimed:** QR session creation/polling/claim/proof endpoints, QR rendering and scanning UI, approved replacement API, identity/QR anti-phishing checks, camera-free scanner integration, true end-to-end test. Existing one-time parent code remains a fallback until these are implemented and tested. The child-generated QR screen must be hidden/disabled as a production action until it is connected to a signed, single-use server session.

## State and testing

`UNPAIRED` → `QR_INVITATION_PENDING` → `PARENT_APPROVED` → `PROOF_PENDING` → `PAIRED_INACTIVE` → `MONITORING_ACTIVE` *only after independent release, OS, legal and consent gates*. All failures/timeouts return to a non-monitoring state and invalidate unspent invitations.

Tests: two concurrent QR approvals for one child; two devices attempting activation; QR replay/expiry/cross-child claim; parent revoked between scan/proof; 108th/109th admission; proof with another public key; child reinstall/Keystore reset; parent replacement; unpair/erasure log; anti-screenshot misuse; no IMEI permission; no child personal data in QR. Do not use real child/device data in CI.

Official Android references: https://developers.google.com/ml-kit/vision/barcode-scanning/code-scanner and https://developer.android.com/identity/user-data-ids .

**Release status:** No QR-based production pairing is active; no Play Store publication is implied.
