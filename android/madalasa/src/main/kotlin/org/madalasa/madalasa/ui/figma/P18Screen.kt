package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * P-18: Plans and app settings.
 *
 * Approved 2026-11-04 free-first plan preview: regular list prices ₹99/month and ₹999/year per
 * paid child, "Pay now" opens Coming Soon only. No billing client, order API, coupon, trial or
 * entitlement grant is reachable from this screen, and server-side FREE_ONLY enforcement stays
 * authoritative.
 *
 * TODO(INTEGRATION/API): Play product details and backend verified subscriptions once billing
 * is approved; nothing here may be swapped for a live checkout without legal and Play signoff.
 * Acceptance: no seats or entitlements granted until a verified paid state exists.
 */
@Composable fun P18Screen(modifier: Modifier = Modifier) = PremiumPlanPreviewScreen(modifier)
