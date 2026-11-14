#!/usr/bin/env python3
"""L10-006: Local fake Google Play purchase provider and entitlement store.

Acceptance: "No live Google charge or API credential"
Pure local synthetic provider for testing subscription verification and
entitlements without touching Google Play Developer API or live credit cards.
All tokens are strictly prefixed with 'synthetic-play:'.
"""
from __future__ import annotations

import time
import uuid
from dataclasses import dataclass, field
from enum import IntEnum
from typing import Any, Dict, Optional


class SubscriptionState(IntEnum):
    UNSPECIFIED = 0
    ACTIVE = 1
    CANCELED = 2
    IN_GRACE_PERIOD = 3
    ON_HOLD = 4
    PAUSED = 5
    EXPIRED = 6


class NotificationType(IntEnum):
    RECOVERED = 1
    RENEWED = 2
    CANCELED = 3
    PURCHASED = 4
    ON_HOLD = 5
    IN_GRACE_PERIOD = 6
    RESTARTED = 7
    PRICE_CHANGE_CONFIRMED = 8
    DEFERRED = 9
    PAUSED = 10
    PAUSE_SCHEDULE_CHANGED = 11
    REVOKED = 12
    EXPIRED = 13


SUPPORTED_SKUS = {
    "plan_monthly": {"price_paise": 9900, "founding_paise": 5000, "duration_days": 30, "kind": "BASE"},
    "plan_yearly": {"price_paise": 99900, "founding_paise": 50000, "duration_days": 365, "kind": "BASE"},
    "addon_viewer_100d": {"price_paise": 10000, "founding_paise": 10000, "duration_days": 100, "kind": "ADDON"}
}

SYNTHETIC_TOKEN_PREFIX = "synthetic-play:"


@dataclass
class SyntheticSubscription:
    purchase_token: str
    order_id: str
    package_name: str
    subscription_id: str
    family_id: str
    child_id: str
    state: SubscriptionState
    start_time_millis: int
    expiry_time_millis: int
    auto_renewing: bool
    price_currency_code: str = "INR"
    price_amount_micros: int = 99000000
    acknowledged: bool = True
    is_founding: bool = False

    def to_developer_api_v2_dict(self) -> Dict[str, Any]:
        """Mimics the Google Play Developer API SubscriptionPurchaseV2 resource."""
        state_str_map = {
            SubscriptionState.ACTIVE: "SUBSCRIPTION_STATE_ACTIVE",
            SubscriptionState.CANCELED: "SUBSCRIPTION_STATE_CANCELED",
            SubscriptionState.IN_GRACE_PERIOD: "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
            SubscriptionState.ON_HOLD: "SUBSCRIPTION_STATE_ON_HOLD",
            SubscriptionState.PAUSED: "SUBSCRIPTION_STATE_PAUSED",
            SubscriptionState.EXPIRED: "SUBSCRIPTION_STATE_EXPIRED",
            SubscriptionState.UNSPECIFIED: "SUBSCRIPTION_STATE_UNSPECIFIED"
        }
        return {
            "kind": "androidpublisher#subscriptionPurchaseV2",
            "startTime": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(self.start_time_millis / 1000.0)),
            "subscriptionState": state_str_map.get(self.state, "SUBSCRIPTION_STATE_ACTIVE"),
            "latestOrderId": self.order_id,
            "lineItems": [
                {
                    "productId": self.subscription_id,
                    "expiryTime": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(self.expiry_time_millis / 1000.0)),
                    "autoRenewingPlan": {
                        "autoRenewEnabled": self.auto_renewing
                    } if self.auto_renewing else None
                }
            ],
            "acknowledgementState": "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" if self.acknowledged else "ACKNOWLEDGEMENT_STATE_PENDING",
            "testPurchase": {"synthetic": True, "charge_amount": 0}
        }


class FakePlayProvider:
    """In-memory synthetic purchase provider and Google Play API emulator."""

    def __init__(self, package_name: str = "org.madalasa.madalasa"):
        self.package_name = package_name
        self._subscriptions: Dict[str, SyntheticSubscription] = {}
        self._order_counter = 1000

    def purchase_subscription(
        self,
        family_id: str,
        child_id: str,
        sku: str,
        is_founding: bool = False,
        now_millis: Optional[int] = None
    ) -> SyntheticSubscription:
        """Executes a synthetic purchase without real payment processing."""
        if sku not in SUPPORTED_SKUS:
            raise ValueError(f"Unsupported SKU '{sku}'. Supported: {list(SUPPORTED_SKUS.keys())}")

        if not family_id or not child_id:
            raise ValueError("family_id and child_id must be non-empty identifiers")

        now = now_millis if now_millis is not None else int(time.time() * 1000)
        sku_info = SUPPORTED_SKUS[sku]
        duration_ms = sku_info["duration_days"] * 24 * 3600 * 1000

        self._order_counter += 1
        order_id = f"GPA.{self._order_counter:04d}-{now % 100000:05d}"
        nonce = uuid.uuid4().hex[:12]
        token = f"{SYNTHETIC_TOKEN_PREFIX}sub:{family_id}:{child_id}:{sku}:{nonce}"

        price_paise = sku_info["founding_paise"] if is_founding else sku_info["price_paise"]
        price_micros = price_paise * 10000

        sub = SyntheticSubscription(
            purchase_token=token,
            order_id=order_id,
            package_name=self.package_name,
            subscription_id=sku,
            family_id=family_id,
            child_id=child_id,
            state=SubscriptionState.ACTIVE,
            start_time_millis=now,
            expiry_time_millis=now + duration_ms,
            auto_renewing=True if sku_info["kind"] == "BASE" else False,
            price_amount_micros=price_micros,
            is_founding=is_founding
        )
        self._subscriptions[token] = sub
        return sub

    def get_subscription_v2(self, package_name: str, token: str) -> Optional[Dict[str, Any]]:
        """Simulates GET /androidpublisher/v3/applications/{packageName}/purchases/subscriptionsv2/tokens/{token}."""
        if package_name != self.package_name:
            return None

        # Fail closed on any non-synthetic token
        if not isinstance(token, str) or not token.startswith(SYNTHETIC_TOKEN_PREFIX):
            return None

        sub = self._subscriptions.get(token)
        if not sub:
            return None

        return sub.to_developer_api_v2_dict()

    def cancel_subscription(self, token: str) -> bool:
        """Transitions subscription to CANCELED (remains active until expiry)."""
        sub = self._subscriptions.get(token)
        if not sub or sub.state == SubscriptionState.EXPIRED:
            return False
        sub.state = SubscriptionState.CANCELED
        sub.auto_renewing = False
        return True

    def expire_subscription(self, token: str) -> bool:
        """Transitions subscription to EXPIRED."""
        sub = self._subscriptions.get(token)
        if not sub:
            return False
        sub.state = SubscriptionState.EXPIRED
        sub.auto_renewing = False
        return True

    def renew_subscription(self, token: str, now_millis: Optional[int] = None) -> bool:
        """Extends subscription by another term."""
        sub = self._subscriptions.get(token)
        if not sub or sub.state == SubscriptionState.EXPIRED:
            return False
        sku_info = SUPPORTED_SKUS.get(sub.subscription_id)
        if not sku_info:
            return False
        duration_ms = sku_info["duration_days"] * 24 * 3600 * 1000
        now = now_millis if now_millis is not None else int(time.time() * 1000)
        sub.state = SubscriptionState.ACTIVE
        sub.expiry_time_millis = max(sub.expiry_time_millis, now) + duration_ms
        return True
