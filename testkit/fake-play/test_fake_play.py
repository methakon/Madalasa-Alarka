#!/usr/bin/env python3
"""L10-006: Automated tests for fake Play purchase provider and RTDN webhook.

Acceptance: "No live Google charge or API credential"
"""
import unittest

from fake_play_provider import (
    FakePlayProvider,
    NotificationType,
    SubscriptionState,
    SYNTHETIC_TOKEN_PREFIX,
    SUPPORTED_SKUS
)
from fake_play_webhook import FakePlayWebhookEmitter


class FakePlayProviderTests(unittest.TestCase):

    def setUp(self):
        self.provider = FakePlayProvider()
        self.family_id = "11111111-1111-1111-1111-111111111111"
        self.child_id = "22222222-2222-2222-2222-222222222222"

    def test_purchase_monthly_subscription(self):
        sub = self.provider.purchase_subscription(self.family_id, self.child_id, "plan_monthly")
        self.assertTrue(sub.purchase_token.startswith(SYNTHETIC_TOKEN_PREFIX))
        self.assertTrue(sub.order_id.startswith("GPA."))
        self.assertEqual(SubscriptionState.ACTIVE, sub.state)
        self.assertTrue(sub.auto_renewing)
        self.assertEqual(99000000, sub.price_amount_micros)

    def test_purchase_founding_rate(self):
        sub = self.provider.purchase_subscription(self.family_id, self.child_id, "plan_monthly", is_founding=True)
        self.assertTrue(sub.is_founding)
        self.assertEqual(50000000, sub.price_amount_micros)  # ₹50 founding rate

    def test_purchase_addon_viewer(self):
        sub = self.provider.purchase_subscription(self.family_id, self.child_id, "addon_viewer_100d")
        self.assertFalse(sub.auto_renewing)  # Addon does not auto-renew
        self.assertEqual(100000000, sub.price_amount_micros)

    def test_unsupported_sku_raises_error(self):
        with self.assertRaises(ValueError):
            self.provider.purchase_subscription(self.family_id, self.child_id, "invalid_sku")

    def test_empty_identifiers_raise_error(self):
        with self.assertRaises(ValueError):
            self.provider.purchase_subscription("", self.child_id, "plan_monthly")
        with self.assertRaises(ValueError):
            self.provider.purchase_subscription(self.family_id, "", "plan_monthly")

    def test_get_subscription_v2_resource(self):
        sub = self.provider.purchase_subscription(self.family_id, self.child_id, "plan_yearly")
        data = self.provider.get_subscription_v2("org.madalasa.madalasa", sub.purchase_token)
        self.assertIsNotNone(data)
        self.assertEqual("androidpublisher#subscriptionPurchaseV2", data["kind"])
        self.assertEqual("SUBSCRIPTION_STATE_ACTIVE", data["subscriptionState"])
        self.assertTrue(data["testPurchase"]["synthetic"])
        self.assertEqual(0, data["testPurchase"]["charge_amount"])

    def test_fail_closed_on_non_synthetic_token(self):
        # A live or arbitrary Google token must be strictly rejected
        real_looking_token = "inapp:real.google.token.should.never.be.accepted"
        data = self.provider.get_subscription_v2("org.madalasa.madalasa", real_looking_token)
        self.assertNull = self.assertIsNone(data)

    def test_cancel_and_renew_lifecycle(self):
        sub = self.provider.purchase_subscription(self.family_id, self.child_id, "plan_monthly")
        self.assertTrue(self.provider.cancel_subscription(sub.purchase_token))
        self.assertEqual(SubscriptionState.CANCELED, sub.state)
        self.assertFalse(sub.auto_renewing)

        # Renewing restores active state
        self.assertTrue(self.provider.renew_subscription(sub.purchase_token))
        self.assertEqual(SubscriptionState.ACTIVE, sub.state)

    def test_expire_subscription(self):
        sub = self.provider.purchase_subscription(self.family_id, self.child_id, "plan_monthly")
        self.assertTrue(self.provider.expire_subscription(sub.purchase_token))
        self.assertEqual(SubscriptionState.EXPIRED, sub.state)
        # Expired subscription cannot be renewed
        self.assertFalse(self.provider.renew_subscription(sub.purchase_token))


class FakePlayWebhookTests(unittest.TestCase):

    def setUp(self):
        self.emitter = FakePlayWebhookEmitter()
        self.token = "synthetic-play:sub:family1:child1:plan_monthly:abc12345"

    def test_emit_and_parse_pubsub_envelope(self):
        envelope = self.emitter.emit_pubsub_envelope(
            notification_type=NotificationType.PURCHASED,
            purchase_token=self.token,
            subscription_id="plan_monthly"
        )
        self.assertIn("message", envelope)
        self.assertIn("data", envelope["message"])

        parsed = self.emitter.parse_pubsub_envelope(envelope)
        self.assertEqual("org.madalasa.madalasa", parsed["packageName"])
        notif = parsed["subscriptionNotification"]
        self.assertEqual(int(NotificationType.PURCHASED), notif["notificationType"])
        self.assertEqual(self.token, notif["purchaseToken"])
        self.assertEqual("plan_monthly", notif["subscriptionId"])

    def test_reject_non_synthetic_token_in_webhook(self):
        with self.assertRaises(ValueError):
            self.emitter.create_subscription_notification(
                NotificationType.RENEWED,
                "real_live_token_12345",
                "plan_monthly"
            )

    def test_malformed_envelope_fails_closed(self):
        with self.assertRaises(ValueError):
            self.emitter.parse_pubsub_envelope({})
        with self.assertRaises(ValueError):
            self.emitter.parse_pubsub_envelope({"message": {}})
        with self.assertRaises(ValueError):
            self.emitter.parse_pubsub_envelope({"message": {"data": "not-valid-base64-json"}})


if __name__ == "__main__":
    unittest.main()
