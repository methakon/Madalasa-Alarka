# Alarka — Child Android module scaffold

**Not implemented, no Gradle module/manifest or APK.** This folder is reserved for a Kotlin-based Android companion. Planned packages: `onboarding`, `capabilities`, `permissions`, `location`, `usage`, `sync`, `network`, `security`, `sos`; actual source names and Android applicationId require approval.

**Execution boundaries:** Android must own runtime permission dialogs and OS indicators; do not add hidden capture code. Adapter collects only eligible location fixes into actual encrypted local queue, then uploads bounded JSON batches where Android permits. Legal/policy feature flags OFF by default. Device Owner is an explicit provisioned DPC role, not a setup toggle.

Definition of first runnable milestone: signed debug build with read-only compatibility check, pairing-independent mock states, synthetic tests, accessible permissions explanation, no child telemetry. Then implement authenticated M1 pairing and durable queue under tested design and legal gates. C++ NDK is optional for validated portable code, not for Android permissions.
