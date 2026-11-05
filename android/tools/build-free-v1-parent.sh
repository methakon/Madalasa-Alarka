#!/usr/bin/env bash
# Parent-only build. Does not contact devices, databases or a tracking API.
set -euo pipefail
ANDROID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ANDROID_DIR"
OUT="$ANDROID_DIR/artifacts/free-v1-parent"
mkdir -p "$OUT"
# Explicit empty public configuration produces a clearly labelled synthetic preview.
# For an approved HTTPS lab build, set both non-secret environment settings below.
ARGS=(--no-daemon --max-workers=2
  "-PmadalasaApiOrigin=${MA_PARENT_API_ORIGIN:-}"
  "-PmadalasaGoogleWebClientId=${MA_GOOGLE_WEB_CLIENT_ID:-}"
  :madalasa:testDebugUnitTest :madalasa:assembleDebug :madalasa:assembleDebugAndroidTest)
./gradlew "${ARGS[@]}" "$@" 2>&1 | tee "$OUT/build.txt"
cp madalasa/build/outputs/apk/debug/madalasa-debug.apk "$OUT/"
cp madalasa/build/outputs/apk/androidTest/debug/madalasa-debug-androidTest.apk "$OUT/"
python3 - <<'PY'
from pathlib import Path
import datetime, hashlib, json, os, subprocess, xml.etree.ElementTree as ET
out=Path('artifacts/free-v1-parent')
def git(*args): return subprocess.check_output(['git',*args],text=True).strip()
roots=[ET.parse(p).getroot() for p in Path('madalasa/build/test-results/testDebugUnitTest').glob('TEST-*.xml')]
counts={k:sum(int(r.attrib.get(k,0)) for r in roots) for k in ['tests','failures','errors','skipped']}
assert counts['tests'] and not counts['failures'] and not counts['errors'], counts
files={p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(out.glob('*.apk'))}
(out/'SHA256SUMS').write_text(''.join(f"{v['sha256']}  {k}\n" for k,v in files.items()))
result={'source_commit':git('rev-parse','HEAD'),'android_tree':git('rev-parse','HEAD:android'),
 'working_tree_status':git('status','--porcelain'),'branch':git('branch','--show-current'),
 'main':git('rev-parse','origin/main'),'dev':git('rev-parse','origin/dev'),
 'built_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'configuration':'approved HTTPS lab' if os.environ.get('MA_PARENT_API_ORIGIN') else 'synthetic preview; no backend configured',
 'jvm_tests':counts,'instrumented_tests':'COMPILED; NOT_RUN (no device connections authorized)',
 'device_tests':'NOT_RUN','live_https_e2e':'NOT_RUN','artifacts':files}
(out/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
(out/'INSTRUCTIONS.txt').write_text('''Parent Free V1 debug lab artifacts; not a release approval.
Rebuild from repository root: bash android/tools/build-free-v1-parent.sh
Requires JDK 17 and Android SDK platform 36; android/local.properties must name the SDK.
The checked-in wrapper pins the Gradle/toolchain versions. Gradle may fetch trusted dependencies.
Use --offline after dependencies are cached. Hashes identify these exact APK bytes;
debug signing keys and ZIP timestamps can change hashes on another machine.
Unconfigured APK: synthetic development preview only. No live tracking API or map provider.
For approved real-development HTTPS testing, rebuild with MA_PARENT_API_ORIGIN and
MA_GOOGLE_WEB_CLIENT_ID set to the approved origin and public OAuth web client ID.
Never embed credentials or bearer tokens. Sign in normally; session stays in process memory.
No real minors, billing, media, database changes or device provisioning are authorized.

Owner-only follow-up (NOT_RUN here; no device connections made):
Install the app/test APKs on an owner-controlled Android 10+ device under the lab handoff.
Run instrumented smoke: cd android && ./gradlew :madalasa:connectedDebugAndroidTest
1. Child selection: tap the desired admitted profile. Verify selected nickname and exact
   child action labels; no first-child fallback. Pairing must not require a location observation.
2. Explore plans from a WAITLISTED child-selection screen and from Settings. Verify
   monthly 99 and yearly 999 list prices, selected benefits, Pay now -> Coming Soon,
   Close and Got it dismiss. No checkout, entitlement, trial or queue priority change.
3. Open location: no configured map provider must show Map unavailable, not a fake map.
   With approved backend sign-in verify observed/received timestamps, age, last-known
   coordinates and unknown/unavailable states. History is latest <=200 server rows from
   six hours; has_more is labelled partial, with no invented pagination or retention TTL.
4. Switch children, revoke authority server-side then refresh, background/resume,
   expire the session and lose network: old child coordinates/history must not reappear.
5. Repeat taps at 320/360dp, 200% font and TalkBack. Record actual PASS/FAIL plus redacted
   screenshots. Do not share IDs, precise GPS, tokens or private household data.
Runtime UI, device matrix, live HTTPS/RLS e2e, legal/Play approval and production release
remain NOT_RUN/OPEN. JVM/parser tests and compilation are not device acceptance.
''')
print(json.dumps(result,indent=2))
PY
