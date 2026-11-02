# Madalasa upload-key setup — 2026-10-30 IST

Status: local generation and encrypted recovery drill PASS; permanent custody and package-registration suitability BLOCKED. This is setup evidence, not release approval. No APK/AAB was built, no Play account changed, and no certificate or private key was uploaded.

## Identity and provenance

- Application: Madalasa Parent.
- Owner-specified package: `in.berhampore.madalasa`. A certificate does not itself reserve or bind this package.
- Purpose: **upload signing only**, kept separate from Google's distributed-APK app signing identity. Not a debug, Alarka or shared app signing key.
- Alias: `madalasa-upload`.
- Format: PKCS12 (`.p12`), using Java keytool; not a JKS file with a misleading extension.
- Algorithm: RSA 4096, SHA256withRSA, requested validity 10,000 days.
- Generated locally on 2026-10-30 IST, certificate valid from `2026-10-29T20:31:47Z` until `2054-03-16T20:31:47Z`.
- SHA-256 public certificate fingerprint:

  `47:F5:CB:2A:C8:1F:22:88:F2:A5:10:7F:72:EC:7D:52:E1:17:38:F5:2C:15:F5:E1:9A:80:AF:B9:2C:5D:F3:A6`

The repository signing policy, Android README, tracked signing/build filenames, designated signing location, project tree and local Android key location were inspected before generation. No approved permanent upload key was found in that scope. The Android debug keystore and SDK template certificate were not adopted. External password managers, offline custody and the Play account were not inspected; a pre-existing externally held key is not ruled out. If one is subsequently identified, reconcile identity and provenance before registering this key; do not silently replace an enrolled key.

Java was absent. Ubuntu's configured archive supplied `openjdk-21-jre-headless` version `21.0.12.1+1-1~24.04.4`, downloaded and extracted project-locally without system installation. The extracted runtime's configuration links were rebased locally. The one-shot generation tool refuses existing signing material and never logs secret subprocess output.

## Private local custody

These paths identify files; none of their private contents belongs in Git, chat, support tickets or CI logs.

- Keystore: `~/.config/madalasa-alarka/signing/madalasa-upload.p12`.
- Keystore password file: `~/.config/madalasa-alarka/signing/madalasa-upload.password`.
- Exported public certificates: `~/.config/madalasa-alarka/signing/madalasa-upload-certificate.pem` and `.der`.
- Public-only machine-readable records: `madalasa-upload-public-record.json` and `recovery-drill-public-result.json` in the same directory.
- Encrypted backup: `~/.config/madalasa-alarka/signing/backups/madalasa-upload.signing-backup.tar.gpg`.
- Independent backup decryption secret: `~/.config/madalasa-alarka/recovery/madalasa-upload.recovery-secret`.

Dedicated signing, backup and recovery directories are mode 0700; material files are mode 0600. Keystore password and backup decryption secret were independently generated with Python `secrets`, using 48 and 64 random bytes respectively. Their values were never printed. The password is supplied to keytool through `-storepass:file`, not a literal command-line value. Local mode bits do not establish full-disk encryption, MFA, offsite redundancy or protection against an administrator/malware with account access.

## Verification actually performed

1. Java `keytool -list -v -keystore <private path> -alias madalasa-upload -storepass:file <password file>` confirms a PrivateKeyEntry and the SHA-256 fingerprint above.
2. Exported PEM and DER public certificates using `keytool -exportcert`.
3. Independently matched OpenSSL `x509 -inform DER -noout -fingerprint -sha256` and SHA-256 of the exported DER bytes to the keytool result.
4. Verified RSA size, self-signature and certificate validity from the exported certificate.
5. Created an in-memory tar containing the keystore, its password, both public certificates and public identity metadata. No plaintext tar was written to disk.
6. Encrypted with GnuPG AES256, iterated/salted SHA512 S2K, requested count 65,011,712 and a distinct random recovery secret.
7. Decrypted and compared every archive byte; restored files into a restricted temporary directory; reopened the restored keystore using its restored password and alias.
8. Loaded the restored private key in memory, signed a fresh random challenge and verified it against the original public certificate. No APK or release artifact was created. Temporary restored files were removed; deletion does not promise forensic erasure from SSD/snapshots.

## Backup and recovery procedure

The current archive and recovery secret are **on the same machine**. The successful drill proves recoverability from these bytes, not independent disaster recovery. Permanent adoption remains BLOCKED until the owner places the encrypted archive on an independently secured offline/offsite destination and places the recovery secret in a separate trusted password manager or independently controlled recovery store. Do not keep the only archive and secret together. Assign a custodian and verify recovery from those actual destinations before marking the key permanent. No remote transfer was attempted.

Recovery on a trusted machine:

1. Obtain the encrypted archive and the separately stored recovery secret through their respective custodians. Do not pass secret values through chat or command-line literals.
2. Set `umask 077` and create an empty mode-0700 recovery directory outside any repository; keep any temporary plaintext archive there.
3. Run `gpg --batch --pinentry-mode loopback --passphrase-file <private recovery-secret file> --output <private temporary tar> --decrypt <encrypted backup>`.
4. Inspect tar member **names only** before extraction. Expect exactly the five basenames documented above: keystore, password, PEM, DER and public record. Reject absolute paths, traversal paths and links. Extract only into the empty private directory.
5. Run keytool lookup with `-storepass:file <restored password file>` and the alias above; compare its SHA-256 with this record. Use OpenSSL on the restored DER to independently compare the fingerprint again.
6. Verify actual private-key possession through a local sign/verify challenge before resuming any authorized signing. Never use app publication as the recovery test.
7. Apply directory/file mode 0700/0600. Remove temporary plaintext tar and trial restoration when finished. Preserve the independently secured encrypted backup and recovery secret.
8. On suspected disclosure, stop signing and follow Google Play's upload-key reset process; do not replace the app signing identity as a shortcut.

For future backups, create the same five-member archive in memory and encrypt using the separately held secret. Do not store an unencrypted archive beside the key. Repeat the recovery drill after any change and retain the public fingerprint as the continuity check.

## Google Play requirements still outstanding

Official sources checked during setup:

- [Sign your app](https://developer.android.com/studio/publish/app-signing): upload keys sign submissions; Google-managed app signing keys sign distributed APKs. Google recommends separate identities.
- [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en): upload keys must be RSA 2048 bits or greater; this 4096-bit key meets that cryptographic requirement.
- [Registering Android package names](https://support.google.com/googleplay/android-developer/answer/16761053?hl=en): new package registration asks for the app's signing public certificate; existing package registration may require eligibility checks and a signed proof APK.

**Do not automatically paste this upload fingerprint into a field requesting the distributed app signing certificate.** Confirm the actual Console flow and package availability with the account owner. For separate Google-managed Play App Signing, use the Google-managed app signing certificate for a registration that requests that identity; the fingerprint above is for this upload key only. Play enrollment and registration have not occurred. Do not reinterpret this key as the app signing key without a separate recorded decision. An existing-package proof APK would require new authorization because builds/uploads are excluded from this task.

The older [signing policy](APP_SIGNING_AND_KEY_MANAGEMENT_POLICY.md) describes the pre-generation baseline and proposed custody controls. This setup record supersedes its assertion of no local keystore for Madalasa only; it does not claim those production controls are fulfilled.
