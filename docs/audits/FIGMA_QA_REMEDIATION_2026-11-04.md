# Figma QA remediation checkpoint — 2026-11-04

**Figma file:** https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli
**New editable page:** [QA FIXED • FREE V1 • 2026-11-04](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=182-2)
**Related issue:** https://github.com/methakon/Madalasa-Alarka/issues/33

## Implemented in Figma (native editable layers)
A separate, canonical candidate V1 screen set was authored rather than destructively editing historical handoff screens. 19 new editable frames, comprising:
- QR expiry (182:3), replay (182:20), guardian review (182:37), interrupted network (182:54), replacement completion (183:121).
- Slot allocation changed (182:71), admitted setup (182:88).
- Approximate location (182:105), no provider (183:2), background restricted (183:19), permission revoked (183:36).
- SOS queued offline (183:53), delivered but not human-acknowledged (183:70).
- Deletion processing (183:87), partial failure (183:104).
- Hardware motion/gyroscope/fallback (184:2), GNSS/constellation unknown (184:22), camera and mic policy gates (184:42).
- Canonical FREE V1 vs DEFERRED vs ADMIN design release map (184:62).

## Verified
Read-back from Figma after authoring reported all 19 frame IDs. Each uses native editable text, auto-layout and separate editable cards and actions. All 19 have **zero** text nodes geometrically outside their frame bounds, and their direct children fit within the frame heights. Main body text is 14 px; headers 25 px; small captions/status are still 12-13 px. Screenshot generation API for the new nodes succeeded, but a full visual screenshot inspection was unavailable in this environment. Thus do not mark pixel-perfect, contrast, text-clipping/overlap, or assistive-technology checks PASS.

## Distinction from completed release
These screens are *editable Figma design references*, not runnable prototypes or authenticated application behavior. They do not prove legal, Play, OS permission, provider, sensor, GPS, SOS or 108-concurrent-device acceptance.

## Follow-up remains OPEN
1. Approve release-scoped mapping of entire historical 81-screen functional handoff and older 187-screen audit against the new canonical V1 candidate.
2. Complete clickable prototype transitions, disabled states, responsive 320px/360px/large-font, contrast/TalkBack and admin typography remediation.
3. Verify visual screenshots manually in Figma and on physical devices; sign off per-screen acceptance.
4. Implement corresponding backend/Compose state machines, proper permission and expiry handling and negative security tests.
5. Figma AI/Weave integration is not connected to this account; edits were made using connected Figma native editing actions, not a Weave AI run.
