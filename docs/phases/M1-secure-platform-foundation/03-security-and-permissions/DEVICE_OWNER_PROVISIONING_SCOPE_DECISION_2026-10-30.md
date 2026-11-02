# Device Owner Provisioning Scope Decision

**Decision date:** 2026-10-30  
**Decision authority:** Project owner  
**Status:** OWNER_DECIDED; implementation and device verification pending  
**Applies to:** Alarka first release

## Decision

The first release will use ordinary Android installation. Android Device Owner / fully managed provisioning is deferred and excluded from first-release scope.

Alarka may perform a read-only check of the platform's current managed/Device Owner state and report the result to Madalasa. It must distinguish confirmed managed state, confirmed not-managed state, and unavailable/unknown state. A failed or unsupported check must not grant capabilities.

## Why

Device Owner is an Android-managed provisioning role, not an ordinary runtime permission. An application cannot legitimately turn an already-configured personal phone into a Device Owner merely by requesting permissions. Treating legacy Device Administrator or a permission grant as equivalent would be misleading and could create unsafe expectations.

## Required safeguards

- No silent elevation or self-provisioning.
- No in-place conversion of an already-configured personal phone.
- No bypass of Android setup, provisioning, or factory-reset requirements.
- No stealth operation, hidden app identity, or notification/privacy-indicator suppression.
- No capture or viewing of financial-app screens and no bypass of financial-app protections.
- Ordinary Android permissions and OS restrictions remain authoritative in standard mode.

## Future reconsideration

A managed-device edition may be reconsidered only through a new owner decision, documented Android-supported enrollment, eligible-device provisioning (typically during new-device or factory-reset setup), clear guardian involvement, physical-device validation, and separate security, legal and Google Play review. This document does not authorize implementation of that path.

## Acceptance evidence still required

1. Standard-install permission and background-operation tests across selected Android versions and OEMs.
2. Read-only managed-state detection tests for managed, unmanaged, unsupported and error states.
3. Negative tests showing no enrollment or elevation attempt.
4. Verification that app identity, required notifications and OS privacy indicators remain visible.
5. Financial-screen exclusion tests proving fail-closed behavior.

No Android build or physical-device test is claimed by this decision. It resolves product scope only, not technical feasibility, legal compliance or Play approval.

## Related canonical records

- [Blockers and Owner Decisions](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md)
- [Android Compatibility Matrix](ANDROID_COMPATIBILITY_MATRIX.md)
