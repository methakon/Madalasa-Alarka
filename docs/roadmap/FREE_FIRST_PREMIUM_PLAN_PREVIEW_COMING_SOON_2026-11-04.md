# Free-first premium plan preview and Coming Soon checkout gate — 2026-11-04

**Decision:** Supersedes the 2026-11-03 instruction to hide all upgrade/plan previews. The free-first release remains no-charge; only catalog preview and simulated checkout-entry UI are enabled. This amendment does not authorize billing.

## 2026-11-05 OWNER PRIORITY — FINISH THE PREMIUM PREVIEW FIRST

**Approved implementation priority P0.** Finish, test and integrate the existing *Coming Soon* premium-plan preview before new SOS/media feature work. Parent PR #30 has already been merged into `dev`; do not recreate duplicate screens or re-open payment enablement. The deliverable is an accessible, phone-tested preview: plan list and monthly/yearly details at **₹99/month and ₹999/year per paid child**, navigable from Settings and WAITLISTED child entry, both buttons open/dismiss the *Coming Soon* modal, and negative tests prove **zero** purchase/order/subscription/trial/coupon/entitlement action. This is **not** approval to implement actual billing or process money.

Owner reports **two Android phones already physically attached to the Hermes development system with USB debugging enabled**. Worker must inspect `adb devices -l`, verify each device's authorization, OS API/model, and use **separate serial-targeted** builds/install/test runs with one Gradle builder per checkout. Never assume we have remote shell/ADB access from this chat or that a USB device passed testing merely because it is attached. Restrict tests to owner-controlled/consenting adult devices, do not leak serials or personal data into public evidence.

Completion gate: exact `parent`/`dev` head SHA, quiesced build SHA-256 for both artifacts where applicable, screenshots with no personal data, real tap-path PASS/FAIL, 320/360dp + 200% font/TalkBack and accessibility checks, no checkout call on network trace, forged-paid API negative test, merged `dev` cumulative integration acceptance. **Keep payment profile/BillDesk/Play activation out of Free V1.**

## 2026-11-04 implementation checkpoint (Issue #32 / #33)

This UI decision is **approved for design and parent-app implementation**, not payment authorization. Hermes' Issue #32 report concerns backend/security work; it is **not** evidence that the Android parent flow has been built or user-tested. Update the `parent` workstream independently, following `parent → dev → main`, with snapshot, interaction and forged-request negative tests. The `api` branch/PR #34 is under scope-drift hold; that hold must not be bypassed to rush preview UI.

The free-first premium-preview design supersedes earlier Figma wording that removed all upgrade entry points. It does **not** supersede server-enforced `FREE_ONLY`, Play/merchant approval requirements, or the 108-admitted-child queue. Owner approval of a display price is distinct from approval of taxes or real payment settlement.

## Parent UX contract
1. Madalasa visibly offers Upgrade / Explore plans to free users, including waitlisted families, without implying paid priority.
2. Present regular list prices, not discounted or coupon-applied prices: **₹99 per month per paid child** and **₹999 per year per paid child**. Future indicative prices are subject to final approved catalog, tax and Play confirmation; no current purchase offer is implied. Prepaid/manual top-up; no automatic renewal.
3. Selecting a plan opens detailed preview; promised benefits are marked future and contingent on OS, legal, Play and device capability.
4. Pay now is preview only: opens a beautiful Coming Soon overlay. Never invoke Play Billing, BillDesk, web checkout, payment profile, payment method form, order API, coupon apply, entitlement grant or trial.
5. Modal says no charge taken and no subscription activated; current free access unchanged. Both Close and Got it — continue free dismiss.
6. Do not show founding/coupon ₹50/₹500 prices in overview. Coupon, eligibility, taxes and payable amount are deferred to an approved future checkout, if launched.
7. FREE_ONLY backend enforcement remains active; 108 child admission slots never become a purchased bypass. No hidden payments, auto-renew or media.

## Figma evidence
- [Plan overview](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=186-2)
- [Yearly detail](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=186-23)
- [Monthly detail](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=188-2)
- [Coming Soon overlay](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=186-41)
- Free-admission and previous premium-disabled frames on FREE FIRST page revised to link into new plan overview. QA FIXED release-map content amended.

## Verification
Read-back 2026-11-04 confirmed editable plan screens and Figma prototype reactions for navigation, both Pay now overlays, both modal dismissal controls and free-entry navigation. No screen text exceeded new frame bounds. Screenshot export succeeded. A real Android click test, payment-attempt negative test, contrast/TalkBack/large-font audit and backend verification have not been completed.

## Worker acceptance
- Free users can see both regular prices (₹99/₹999), no applied discount.
- Both plan detail previews are reachable; Pay now opens Coming Soon and closes cleanly.
- Under FREE_ONLY no financial transaction, merchant/token request, paid entitlement or trial is created even by forged calls.
- Waitlisted families cannot buy or bypass the 108 child-service cap.
- Full accessibility, localization and device UI tests plus CI evidence before release.
- Essential privacy, support, permission and free safety services remain available without purchase.

**Status:** Figma design/prototype updated; actual app implementation and final visual/accessibility acceptance remain open.