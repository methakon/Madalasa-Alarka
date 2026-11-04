# Free-first premium plan preview and Coming Soon checkout gate — 2026-11-04

**Decision:** Supersedes the 2026-11-03 instruction to hide all upgrade/plan previews. The free-first release remains no-charge; only catalog preview and simulated checkout-entry UI are enabled. This amendment does not authorize billing.

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