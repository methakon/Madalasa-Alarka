# Madalasa–Alarka — Two-Parent Access, Child Seat Assignment and Google Play Billing

**Owner direction, 2026-10-28; status: accepted product intent / engineering and store feasibility pending.** India-first. This design supersedes any historical assumption that each adult needs to buy a plan separately. **No code or Play Console products exist for these decisions yet.**

## Official Google findings (checked 2026-10-28)

1. [Google Family Link: add another parent](https://support.google.com/families/answer/7295768): Google family managers may give an additional adult (18+) parental privileges; both can help manage children in Family Link, while only the family manager grants/removes the second parent.
2. [Google family groups](https://families.google/intl/en_in/families/): Family Link and family groups are related but different products.
3. [Google Play family payments](https://support.google.com/googleplay/answer/15775614): family payment method **cannot buy subscriptions**.
4. [Important India-specific changes](https://support.google.com/googleplay/answer/16719923): Google Play Family Library and family payment method are **no longer available for new signups in India**. Therefore, no Madalasa premium entitlement can depend on Google Play Family Library.
5. [Google Play Billing secure verification](https://developer.android.com/google/play/billing/security): purchase tokens must be checked by the secure server and each verified unique purchase mapped once to an owner; do not rely solely on a local Play account's `queryPurchasesAsync` for family entitlement.
6. [Attach obfuscated account identifiers](https://developer.android.com/google/play/billing/integrate): Google permits `obfuscatedAccountId` / `obfuscatedProfileId`; use pseudonymous server-generated identifiers, never raw email/child IDs in Play.
7. [Prepaid plans](https://developer.android.com/google/play/billing/subscriptions): plans expire and require manual purchase/top-up. [Subscription add-ons](https://developer.android.com/google/play/billing/subscription-with-addons) currently support auto-renewing plans only; do **not** treat prepaid child seats as Play add-on line items.

**Google is NOT a source of trusted third-party guardian relationship membership.** Family Link's second-parent functionality does not imply an available third-party relationship verification API or automatically grant Madalasa monitoring permissions. We found no verified official supported API to import Family Link roles; Madalasa must perform its own invitation/approval and child-specific guardian authorization.

## Commercial policy

- Billing unit is **one eligible paid child seat per covered child**, NOT one per guardian, phone, login session or viewing device.
- **One paying family** may have a primary billing adult and another separate signed-in authorized co-parent (and optionally other scoped adult guardians). When a child has a verified active paid seat, authorized adults share that child's premium entitlement; **never require the second parent to repurchase**.
- Primary billing adult can **select which child IDs** receive N available paid seats via an explicit checklist; switching allocations requires confirmation, short abuse protections and no opportunity to access two children using one seat simultaneously.
- All media limits/quota consumption, where media permitted, apply to **paid child ID across all parents**, not per guardian. Guardians can have distinct privileges (e.g. live location vs media); billing cannot override revoked child-specific permissions.
- First 1,008 qualifying distinct paying *family accounts* remain founding families; founding prices ₹50/month or ₹500/year per eligible paid child, including children added later. Public pricing ₹99/month or ₹999/year per paid child, subject to Play Console confirmation.
- **Manual prepaid only, no auto-renew.** When prepaid expiry is verified, all adults see that child downgraded to free live tracking at reduced/adaptive OS-permitted GPS frequency, with six hours of visible history. No silent renewal and no repeated 48-hour family trial.
- Family status is `FREE | TRIAL | PAID_PREPAID | EXPIRED` per child. Parents' role is independent of payment status; billing and guardian access changes are separate audited operations.

## Data model / ownership boundary (candidate)

```text
family(id, founding_eligible, primary_billing_user_id?)
adult_account(id, identity_provider_subject, verified_adult, status)
family_membership(family_id, adult_id, role, status, verified_at)
guardian_child_grant(family_id, adult_id, child_id, scopes, state, revoked_at)
child(id, family_id, status)
play_purchase(token_hash, purchaser_adult_id, family_id, product_id, expiry_at, state, acknowledged_at)
entitlement_batch(id, family_id, purchase_token_hash, seat_capacity, valid_from, valid_until, status)
seat_assignment(entitlement_batch_id, child_id, assigned_at, unassigned_at)
child_media_usage(child_id, period, kind, delivered_seconds_or_count)
```

Unique active seat assignment per child/family/purchase batch; no purchase token may be attached to multiple unrelated families. Avoid storing raw purchase tokens outside encrypted controlled backend storage; retain protected provider reference for required verification/restore. Tax/fraud logging retention reviewed separately from child routes.

## Parent workflow

1. Parent A creates family, enrolls Child 1, accepts separate monitoring disclosures/guardian authority, and selects a verified, supported prepaid offer for N child seats.
2. Play checkout explicitly identifies purchaser and amount, and never charges automatically. API verifies purchase token/expiry, acknowledges prepaid purchase, and creates N unassigned seat entitlements.
3. The payer selects N child IDs; server atomically assigns slots. Present all eligible children and free/paid state before payment; if no child is selected, do not accidentally grant blanket paid access.
4. Parent A invites Parent B using single-use short-lived signed invite. Parent B signs in to their **own account**; verified adult and appropriate child-specific scopes are checked before accepting. Family Link enrollment alone is insufficient.
5. Parent B opens the covered child: backend returns PAID_PREPAID from the shared **child** entitlement and role scopes. Show **“Covered by your family’s prepaid plan”**, no purchase prompt. Show remaining quota shared between guardians; do not expose billing token or payment method to Parent B.
6. Parent B's device can switch among child profiles **only if explicitly granted**; only covered children are paid; others remain free.
7. Prepaid expiry/revocation/refund or payer account termination removes paid entitlement from all parent views; family/guardian viewing may continue on permitted free features, subject to erasure/guardian revocation. A payer's removal, transfer, or deletion requires a carefully designed purchase-rights/erasure/reconciliation policy.
8. When Parent B tries to buy an already active covered child, show an entitlement explanation, never a second checkout. Backend must guard payment races/refund duplicate unused purchases through valid store mechanisms.

## Prepaid multi-child Google Play product design open gate

Do not assume the same Play prepaid subscription product can be purchased simultaneously multiple times, nor that each child is a Google Family Link profile product. Candidate design: prepaid **family capacity products** for N=1..5, assigned to child IDs by our backend; or separated manual-renewal time-passes subject to Play terms. Need actual Play Console sandbox tests for same-account 1→2 seat expansion, overlap/refund, monthly/annual capacity changes, founding offers, token replacement, ownership transfer, top-ups, manual expiry and restoring to the purchasing Google account. Prepaid add-ons are NOT available through the auto-renew-only Play add-ons feature. Never display an invented Play price/offer.

## Security and authorization acceptance

- Two parent accounts can independently sign in, but one child seat is charged once.
- One guardian never gains another child's location solely because a co-parent shares a paid family plan.
- Revoking a guardian immediately blocks that guardian's old tokens/media commands and pending upload/download links, not the other parent's payment.
- If the payer loses access or account is deleted, no automatic renewal; preserve or end remaining prepaid access according to explicit store rights, privacy constraints and family owner controls.
- Concurrent seat reassignment or duplicate invitations cannot exceed purchased capacity or cause leaked family data.
- Child erasure ends that child's access/ingest, and does not delete required tax data or force a duplicate purchase for an unaffected sibling.
- No Google Family Link/Family Library dependency, no permanent automatic recognition of parent relationships, no coercive invitation requirement.
- Quota across guardians is enforced by a server-side atomic per-child meter; optional camera/microphone/screen capabilities remain release-blocked pending Android, Google Play and legal approval.

## Screen updates

P-06 children switcher; P-16 guardian management; P-39 invitation; P-40 grant detail; P-47 seat assignment; P-48 prepaid checkout; P-49 covered-by-family/expiry; P-54 manual renewal and transfer; P-44 deletion impacts. Child app C-02 must show which adults have access. Existing 81 functional screen handoff should be retained; new visual prototypes are not working UI.

## Superseding requirement — child-specific Google-supported parental sharing (2026-10-28)

Owner clarified that blended families may have different parents for different children; **shared family prepaid seats do NOT automatically give any co-parent access to all children**. Main payer selects each paid child and **separately** chooses that particular child's eligible co-parent. Default hidden/denied for all other child-adult pairs. Old examples above of "Parent B receiving the same eligible features" apply ONLY *after* that precise child–co-parent relationship is officially verified, independently child-scoped authorized, and premium features are available on that child.

**Google limitation:** Family Link allows one family manager to assign another adult parent; Google Sign-In by itself does not attest that a certain adult is a Family Link parent for the particular child. No verified third-party parent-role API has been identified, so the owner’s **Google-supported-parent-only policy is a hard engineering gate, NOT accomplished by any ordinary Google account login**. Do not allow child data sharing if attestation remains unverifiable. Support legitimate custody/authority edge cases through legal/product review, not through widening access by default. [Canonical decision](CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md).

**New separate premium viewing limit:** each paid child includes **one live premium monitoring viewer slot at a time**, independent of how many approved parents have their own accounts. Working optional charge **₹100 one-time per +1 concurrent viewer for up to 30 days** (duration to be confirmed), valid no later than child prepaid expiry and without auto renewal. Each optional slot adds **30 combined audio/video minutes** to that child's jointly metered pool across permitted guardians, with original media feature/legal gates. No extra paid child seat, no unlimited Android screen capturing. Server atomic TTL viewer leases, verified Play one-time purchases and authorization rechecks enforce the limit; free basic location/emergency operations remain accessible. Google Play subscription add-ons cannot implement this with prepaid products. [Implementation and UI specification](CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md).

### 2026-10-28 100-day extra screen commercial correction

The separately purchased extra premium concurrent viewer is **₹100 for exactly 100 calendar days**, not 30 days and **not truncated when the child's main prepaid plan expires**. It stays in the entitlement ledger throughout those 100 days; on a main-plan lapse all premium viewing is temporarily suspended, but unused extra slot and 30 combined A/V minutes resume after voluntary manual main-plan renewal before the 100-day expiry. The add-on does not grant access to any unapproved co-parent or child. Google Play one-time Buy + backend timer, not unsupported 100-day Rent. https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.


## OWNER SUPERSESSION — 2026-10-28: drop Google Family Link parental-role API dependency

**New decision overrides every older claim in this document that a co-parent may be invited ONLY if Google's Family Link parental role is programmatically verified, or that no sharing is possible until a public Family Link attestation API appears.** Google sign-in still verifies each adult independently (`iss/aud/sub/exp`). Madalasa's backend uses an exact-child single-use invitation, separately accepted and revocable scoped grants, device/child transparency, dispute hold, no sibling disclosure and security/authorization tests. **Legal verification of adult parental/lawful guardian authority and valid child-data consent is a distinct mandatory compliance gate, NOT waived**; synthetic local tests may use controlled fixtures, real child processing requires approved lawful method. A paid family seat is never a guardian permission and a second adult never inherits the entire family's children. See [V2 ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) and [India legal brief](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md). Use new versioned DB migration, do not mutate M1 baseline. This is design only; no verified runtime has been built.
