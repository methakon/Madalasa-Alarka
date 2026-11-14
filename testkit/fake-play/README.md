# Fake Play Purchase Provider and RTDN Webhook

**Task:** L10-006 (phase 10) · **Artifact:** `testkit/fake-play/`  
**Acceptance:** *"No live Google charge or API credential"*  

## Overview
This testkit provides a fully self-contained offline simulator for:
1. **Google Play Developer API v2 (`SubscriptionPurchaseV2`)**: Synthetically verifies subscription purchase tokens for base plans (`plan_monthly`, `plan_yearly`) and addons (`addon_viewer_100d`).
2. **Real-time Developer Notifications (RTDN)**: Generates and parses standard Google Cloud Pub/Sub push messages for subscription lifecycle events (`PURCHASED`, `RENEWED`, `CANCELED`, `EXPIRED`).

## Invariants
- **Zero Real Credentials:** Tokens are strictly prefixed with `synthetic-play:`. Any live token format or external credential fails closed.
- **Zero Financial Egress:** Test purchases have `charge_amount = 0` and `synthetic = True`.
- **Founding Rate Support:** Supports founding family rates (₹50/mo, ₹500/yr) alongside standard regular list pricing (₹99/mo, ₹999/yr).

## Running Tests
```bash
python3 -m unittest discover -s testkit/fake-play -p 'test_*.py' -v
```
