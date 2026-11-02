# Android App Signing, Backend Keys and Rotation Policy

> **Document control:** M1 / 03-security-and-permissions · Proposed owner: Security + Android/backend (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** Proposed security policy, no keystore, Play app signing or Android package identifiers configured in repository. **Never commit signing material.**

## Android publisher/release
- Verify legal publisher/merchant identity and developer account ownership. Define stable package IDs for Madalasa and Alarka **before** any signing/enrollment.
- Use Play App Signing with separate upload key wherever eligible; protect release/private signing and Android KeyStore-bound enrollment keys. Document custody and verification without publishing secrets.
- Generate distinct development, internal-test and production signing identities. Test-track build must visibly identify test monitoring; no alternate stealth APK distribution.
- Keys in controlled secret manager/HSM or verified secure CI store with least privilege, MFA, two-person approval for prod release and short-lived access. CI builds of public PRs must never receive signing secrets.
- Record certificate public fingerprints, rotation dates, owner, access approvals and device enrollment impact; **never private keys/passwords**.

## Backend and app/device keys
- HTTPS service TLS managed/rotated independently of Android signing. Pairing credentials bound to device/enrollment generation; time-limited access tokens and per-child guardian authorizations.
- Android Keystore master key per enrolled child device protects local GPS queue; use actual SQLCipher/encrypted envelope implementation, do not assume normal SQLite is encrypted.
- Media streaming (P3 OFF) needs ephemeral session credentials; never save unencrypted content on VPS, nor share TURN long-lived passwords to clients.
- PostgreSQL app uses least-privilege roles, rotated credentials, TLS and secret manager; secure RLS migration admin separated.

## Rotation and compromise
- On suspected leak: stop signing/CI promotion and relevant service, rotate credentials, revoke old enrollment generations and sessions, audit signed artifacts, quarantine compromised CI, check Play upload-key recovery processes and reinstall/upgrade effects.
- Store encrypted offline recovery copy and dual-custody process outside source control; document restore drill.
- Do not silently replace Android signing certificate after live installs; assess app update compatibility and user disruption.
- Reapply account deletion tombstones before replaying 48h offline batches signed under revoked device keys.

## Audit and blockers
Signing event ledger in private access-controlled system: actor/purpose, timestamp UTC, artifact digest, approval, versionCode, review and rollback; secrets omitted. Assign owner/backups, select legal entity, certify key custody, test CI signer, verify Play status, conduct compromise tabletop before release. Unimplemented/NOT TESTED.
