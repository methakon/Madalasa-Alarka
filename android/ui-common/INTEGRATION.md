# Shared UI-only module — integration handoff

These are reusable Compose source files for the parent and child Android apps. This directory does **not** claim to be a buildable Gradle module yet.

1. The Android bootstrap owner must synchronize `parent` and `child` with `main` and `dev` per AGENTS.md and settle shared Gradle-root ownership before changing settings.
2. Add `:ui-common` to `android/settings.gradle.kts`; add an Android library `android/ui-common/build.gradle.kts` with the same AGP/Kotlin/Compose BOM pinned by the bootstrap worker, `compileSdk`, and JUnit test dependency.
3. Add `implementation(project(":ui-common"))` to each application module.
4. Use `MadalasaTheme`, `APTopBar`, `APButton`, `APStatusPanel` and `ScreenState` to build exact Figma screen designs. Preserve English strings as resources when implementing the final screens.
5. For every P-01..P-60, C-01..C-21 and ST-01..ST-05 screen, record navigation ownership, intended API, required legal/OS/auth gate, unavailable/error/offline state and a TODO(INTEGRATION) in the owning screen file.
6. No synthetic UI mock is evidence of permission, pairing, health or GPS status. Do not enable collection, background capture or sensitive functionality.
7. Build both debug apps and execute JVM tests; record commands, exit codes, commit SHA and failed tests. Code must be reviewed into dev before main.

The shared components deliberately do not implement business logic, credential storage, Android permissions or live network calls.
