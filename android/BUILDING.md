# Android synthetic-only scaffold

Two independent Android application modules in `android/`:
- `:madalasa` guardian/parent app
- `:alarka` transparent child-companion app

Gradle 8.13, Android Gradle Plugin 8.13.2, Kotlin Gradle plugin 2.3.20, JDK 17,
compileSdk / targetSdk 36 and minSdk 29 (candidate until Android testing).

From `android/`, with a **locally installed and verified Gradle 8.13**
and installed Android SDK platform 36, run:

```sh
gradle --no-daemon projects
gradle --no-daemon :madalasa:assembleDebug :alarka:assembleDebug
gradle --no-daemon :madalasa:testDebugUnitTest :alarka:testDebugUnitTest
```

Independent workstream branches may contain only one module's
`build.gradle.kts` until integrated. Run that module alone on the branch.

**A Gradle Wrapper JAR / executable is not committed** because a verified
distribution-supplied wrapper binary was unavailable during source-only
GitHub authoring. `gradle/wrapper/gradle-wrapper.properties` pins the version;
generate `gradlew`, `gradlew.bat`, and a verified `gradle-wrapper.jar` using
`gradle wrapper --gradle-version 8.13 --distribution-type bin` in a trusted
build environment and commit them before requiring wrapper builds.
Do not fabricate a wrapper JAR or download from an untrusted mirror.

Both apps are **non-production synthetic prototypes** (application IDs end
in `.synthetic`). No location, microphone, camera, usage access, media
projection, monitoring service, boot or background-access permissions are
declared. There are no live API credentials, child devices or child data;
there is no device enrollment, FCM or actual monitoring.

The visible app icon/label are placeholders for Android build/test work only;
package identifiers, store audience, compliant disclosures, monitoring
metadata and actual permissions require a separate reviewed release
decision. No app-store release permitted from these starter builds.
