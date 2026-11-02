# Madalasa — Guardian Android module scaffold

**Not implemented, no Gradle module/manifest or APK.** Reserved for Kotlin/Compose UI and authenticated client, with explicit per-child guardian grants, timestamps/quality for latest GPS and usage events, feature compatibility, permission status, SOS and event history.

Parent screens must not claim `Live` when child device is offline or when only Postgres durable inbox has ACKed GPS but final PostGIS history is pending. Multiple devices per child preserve individual source/time. Parent media log (metadata-only) may be viewed by scoped guardians when lawfully released; no VPS media archive or hidden sensors. Requesting a child's Android grant does not remotely grant it.

Plan code after Kotlin/AGP, package ID, legal publisher and API versions are chosen. All proposed Figma screens are designs, not proof of a running UI.
