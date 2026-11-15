# Alarka — full free Android child companion

**2026-11-03 owner direction:** The child app is **always free to install and fully implement**. BillDesk, subscription and premium feature delivery must never delay child-app development or introduce payments inside Alarka. The 108-child cap applies only to active server-admitted child profiles, never app downloads or opening setup/privacy screens.

## Two independent lifecycles

1. **Installation:** Anyone eligible may install/open the child app. Disclosure, privacy details, installation compatibility, child-side settings and pairing setup remain available with no subscription and no parent pairing. This state must do **no** monitoring, uploading, background location, mic/camera/screen capture or remote commands.
2. **Service activation:** A verified guardian first signs up a child profile, obtains one of the global 108 child-service slots, confirms lawful authority/consent, and obtains a server-issued, expiring one-time pairing code. The installed child app submits that code to `POST /v1/enrollment`, proves possession of its own Android Keystore P-256 key via `POST /v1/enrollment/{enrollmentId}/proof`, and receives a scoped short-lived server device token. The 10-character parent-issued code is from the literal alphabet `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`. A six-digit code is **only** a debug preview. A successful pairing is **not** permission to begin monitoring.
3. **Monitoring:** Only after fresh device proof, exact child ADMITTED status, current parent authority/consents, purpose-specific server permission, platform/legal approval, Android runtime permissions and an accurately ongoing monitoring notification can a service start. Expiration, lost signal, revoked consent, missing admission, unsupported Android mode and policy failures must stop service and uploads. Local sign-out clears Keystore credentials immediately but is not falsely presented as confirmed backend revocation; the guardian must revoke the device in Madalasa.
4. **Waiting list:** Parent can finish signup after 108 slots fill, but `WAITLISTED` children cannot pair or start services. Child app remains installable and shows setup and privacy screens. Following FIFO promotion, the guardian must initiate pairing and authorization.
5. **Subscription:** There is **no** billing API/SDK, payment-profile dependency or purchase UI in Alarka. Later guardian-side paid changes cannot bypass child consent/OS requirements.

## What the current source does (not a claim of Play production readiness)

- Android/Compose navigation and screen inventory; disclosed app identity, compatibility and permission pages.
- `ChildPairingPolicy` accepts real ten-character parent codes while restricting six-digit synthetics to explicit debug mode.
- `KeystoreAlarkaEnrollmentService` implements HTTPS challenge/proof with AndroidKeyStore EC P-256 and AES-GCM protected short-lived credentials. Build with an explicitly reviewed `-PalarkaApiOrigin=https://…`; the property is empty and pairing unavailable in an unconfigured release. A debug build without an API origin uses clearly marked synthetic preview only.
- `ChildMonitoringActivationPolicy` requires all independent gate facts and rejects unpaired, waitlisted, offline, revoked, unconsented and unapproved cases. The backend currently returns `collection_authorized=false`, so real monitoring **remains disabled** even after successful cryptographic pairing.
- A configured app may query `GET /v1/devices/{deviceId}/consent-status` with the cryptographically enrolled device bearer. The response's server state cannot substitute for actual Android grants or Play/legal approval.
- Secure local queue, motion cadence, foreground-service, disclosure and privacy policy code exist but are **not** yet a production GPS collector, permanent notice, network retry/renewal stack or push delivery flow.

## Required completion before Play release

Implement and test actual Android runtime location handling, user-visible persistent foreground notification/service, permission coaching and revocation, OS-conformant location collection and bounded durable encrypted upload, credential renewal/remote revocation, all approved free SOS/check-in capabilities, production release package and signed AAB, 108/109 service rejection, real-device family/child binding, retention/data protection and Play policy review. Reject features that do not meet Google's Families/monitoring and Android policy rather than faking successful capture.

**Never claim:** installed = paired, paired = admitted, admitted = consented, Android permission = lawful data collection, debug = production, notification design = foreground-service implementation, or a committed code branch = Play approval.
