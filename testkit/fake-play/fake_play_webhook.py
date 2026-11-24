#!/usr/bin/env python3
"""L10-006: Real-time Developer Notification (RTDN) Webhook generator and parser.

Acceptance: "No live Google charge or API credential"
Generates standard Cloud Pub/Sub envelopes matching Google Play Developer
notifications without needing live GCP infrastructure or credentials.
"""
from __future__ import annotations

import base64
import json
import time
import uuid
from typing import Any, Dict

from fake_play_provider import NotificationType, SYNTHETIC_TOKEN_PREFIX


class FakePlayWebhookEmitter:
    """Emits synthetic Cloud Pub/Sub messages containing Google Play RTDN payloads."""

    def __init__(self, package_name: str = "org.madalasa.madalasa"):
        self.package_name = package_name

    def create_subscription_notification(
        self,
        notification_type: NotificationType,
        purchase_token: str,
        subscription_id: str,
        event_time_millis: int | None = None
    ) -> Dict[str, Any]:
        """Creates the decoded developer notification dict."""
        if not purchase_token.startswith(SYNTHETIC_TOKEN_PREFIX):
            raise ValueError(f"purchase_token must start with '{SYNTHETIC_TOKEN_PREFIX}'")

        now = event_time_millis if event_time_millis is not None else int(time.time() * 1000)
        return {
            "version": "1.0",
            "packageName": self.package_name,
            "eventTimeMillis": str(now),
            "subscriptionNotification": {
                "version": "1.0",
                "notificationType": int(notification_type),
                "purchaseToken": purchase_token,
                "subscriptionId": subscription_id
            }
        }

    def emit_pubsub_envelope(
        self,
        notification_type: NotificationType,
        purchase_token: str,
        subscription_id: str,
        subscription_path: str = "projects/madalasa-local/subscriptions/play-rtdn"
    ) -> Dict[str, Any]:
        """Wraps the RTDN payload into a standard GCP Cloud Pub/Sub push notification envelope."""
        rtdn_dict = self.create_subscription_notification(notification_type, purchase_token, subscription_id)
        raw_bytes = json.dumps(rtdn_dict).encode("utf-8")
        encoded_data = base64.b64encode(raw_bytes).decode("ascii")

        message_id = str(uuid.uuid4().int)[:16]
        publish_time = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())

        return {
            "message": {
                "data": encoded_data,
                "messageId": message_id,
                "publishTime": publish_time,
                "attributes": {
                    "synthetic": "true",
                    "source": "fake-play"
                }
            },
            "subscription": subscription_path
        }

    @staticmethod
    def parse_pubsub_envelope(envelope: Dict[str, Any]) -> Dict[str, Any]:
        """Parses and validates incoming Pub/Sub envelope. Fails closed on invalid payloads."""
        if not isinstance(envelope, dict) or "message" not in envelope:
            raise ValueError("Malformed Pub/Sub envelope: missing 'message'")

        msg = envelope["message"]
        if "data" not in msg:
            raise ValueError("Malformed Pub/Sub envelope: missing 'data' in message")

        try:
            raw_bytes = base64.b64decode(msg["data"])
            payload = json.loads(raw_bytes.decode("utf-8"))
        except Exception as e:
            raise ValueError(f"Failed to decode base64 RTDN payload: {e}")

        sub_notif = payload.get("subscriptionNotification")
        if not sub_notif:
            raise ValueError("Payload missing 'subscriptionNotification'")

        token = sub_notif.get("purchaseToken", "")
        if not token.startswith(SYNTHETIC_TOKEN_PREFIX):
            raise ValueError(f"Rejected non-synthetic token in notification: {token}")

        return payload
