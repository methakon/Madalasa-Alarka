# P-04 — Google account handoff: Android implementation and verification

**Date:** 2026-11-02  
**Figma:** [P-04 Google account handoff, node 9:147](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=9-147)  
**Owner:** Madalasa Android / `parent` workstream  
**Source status:** Kotlin implementation committed to `parent`. **Actual Google sign-in on a registered dev device and server has NOT been demonstrated.** Do not use this document as Play approval or guardian-authorization evidence.

## Screen-to-code mapping

| Figma element | Code and actual behavior |
|---|---|
| Account chooser | `android/madalasa/src/main/kotlin/org/madalasa/madalasa/ui/figma/P04Screen.kt`; invokes Google Credential Manager only on user tap and when both development config values are valid |
| Profile indicator | Shows no verified identity before server acceptance; afterwards shows a Google-supplied display label and expressly does not claim guardian authority |
| Guardian disclosure | Expandable explanation that Google login does not prove lawful parenthood or authorize child-scoped monitoring |
| Verification status | Explicit pending/cancelled/unavailable/invalid/rejected/accepted states; failures never produce a parent session |
| Continue securely | Figma-colored Compose primary control; disabled when client ID, HTTPS API, Activity or session sink is unavailable |
| HTTPS exchange | `android/madalasa/src/main/kotlin/org/madalasa/madalasa/api/GoogleParentHandoff.kt`; POST `/v1/auth/parent/google` with signed Google ID token in Bearer header and `{}` body |
| Session acceptance | Bounded response, HTTP 201, PARENT/ACTIVE/Bearer shape, 64-character opaque token, actor UUID and future expiration; process memory only |
| Guardian/child access | **Not granted** by P-04. Existing SQL memberships, child-specific grants and consent controls remain independent gates |

**Integrations:** `DefaultAppContainer`, `MainActivity`, `MadalasaNavHost`, `P02Screen` and `AuthenticationScreen` provide route `google_handoff`; P-02's Google button navigates to P-04. The existing *separately labeled* synthetic development login is unchanged and MUST NOT be relabeled verified. The privacy gateway may use a short-lived session from the in-memory store, but it must still ask the server for authorized child-scoped data. No child data is automatically opened after sign-in.

## Dependencies and development configuration

The repository uses Android Gradle Plugin 8.7.3, Kotlin 2.0.20, AndroidX Credential Manager **1.6.0** and Google ID SDK **1.1.1**. Google ID SDK 1.2.1 is NOT compatible with the pinned Kotlin compiler (its metadata was compiled with a newer Kotlin version); use the pinned 1.1.1 unless the entire Android toolchain is intentionally upgraded and verified. Official sources: [Android Credential Manager Sign in with Google](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation), [Credential Manager releases](https://developer.android.com/jetpack/androidx/releases/credentials), and [Google ID library releases](https://developers.google.com/identity/android-credential-manager/releases).

Configure in the development environment; no OAuth client ID, password, token, APK signing private key or API endpoint secret is committed:

```bash
cd android
./gradlew :madalasa:assembleDebug \
  -PmadalasaGoogleWebClientId='REPLACE_WITH_YOUR_WEB_OAUTH_CLIENT_ID.apps.googleusercontent.com' \
  -PmadalasaApiOrigin='https://replace-with-your-dev-api.example'
```

Equivalent **non-secret** environment variable names are `MA_GOOGLE_WEB_CLIENT_ID` and `MA_PARENT_API_ORIGIN`. The backend must independently configure its expected audience (for example `MA_GOOGLE_OIDC_AUDIENCE` equal to the Web client ID), Google signing-key verification, trusted V2 session issuance, PostgreSQL issuer privileges and HTTPS. Register the development app's Android OAuth credentials/package and signing fingerprint with Google Cloud according to the current official identity documentation. The Android application's synthetic placeholder package ID is not evidence of an approved Play listing or production OAuth brand.

**No configuration:** The app still compiles; the chooser is disabled with an explanation. **Configuration is not authentication:** a real Google account, signed token and accepted developer backend are required for a real successful session.

## Acceptance and follow-up

- [x] P-04 screen-specific Compose structure maps the Figma header, hero, four rows, and primary CTA; navigation from P-02 exists
- [x] Fresh random nonce and Google native chooser path implemented; no hand-crafted fake account list
- [x] One-time HTTPS Google ID-token exchange targets existing C++/PostgreSQL session bridge
- [x] Fail-closed behavior for no config, credential cancellation, unexpected credential, response rejection and expired session
- [x] Unit tests added for route, readiness, origin validation, session expiry and error states
- [ ] Android build/test run **on the final branch commit**: check [parent branch Android Actions](https://github.com/methakon/Madalasa-Alarka/actions/workflows/android-ui-build.yml) for actual result; do not infer a pass from older commits
- [ ] Real adult-operated test phone with an independently registered Google Cloud **development** OAuth configuration: account chooser, server-verified identity, network drop, wrong account, cancel and replay
- [ ] Verify server grants/consents, exact-child RLS and no privacy data from an unrelated family; negative tests and actual `dev` merge candidate
- [ ] Screenshot parity against 9:147, accessibility/large font/dark mode/keyboard/touch, Android lifecycle/rotation
- [ ] Full owner-approved legal purpose, Android/Google Play audience and permission checks for release (not required to write or compile this source)

**Branch flow:** commit Android changes on `parent`, request reviewed `parent` → `dev`, then independently review/test `dev` → `main`. This canonical documentation lives on `main` only. No deployment or Play submission is part of P-04 source work.
