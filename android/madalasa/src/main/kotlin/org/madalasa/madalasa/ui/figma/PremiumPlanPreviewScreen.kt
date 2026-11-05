package org.madalasa.madalasa.ui.figma

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * P-18 / Figma plan preview — approved 2026-11-04.
 *
 * Shows regular list prices to every free user (including waitlisted families) and sends
 * "Pay now" to a Coming Soon overlay. No billing client, checkout, coupon, trial or
 * entitlement is reachable from this screen.
 */
@Composable
fun PremiumPlanPreviewScreen(modifier: Modifier = Modifier) {
    val parchment = Color(0xFFFFF7E7)
    val teal = Color(0xFF087E83)
    val darkTeal = Color(0xFF164950)
    val muted = Color(0xFF6B8585)
    // Compose owns observable UI state. A mutableStateOf wrapper around a mutable
    // ordinary object would NOT recompose when payNow() changes an internal field.
    val preview = remember { PremiumPlanPreviewState() }
    var selectedInterval by remember { mutableStateOf(PlanInterval.MONTHLY) }
    var dialogVisible by remember { mutableStateOf(false) }

    Column(
        modifier = modifier.fillMaxSize().background(parchment)
            .verticalScroll(rememberScrollState()).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("❀  MADALASA   /   PREMIUM", color = darkTeal, fontWeight = FontWeight.SemiBold)
        Text("Explore plans", color = darkTeal, fontWeight = FontWeight.Bold)
        Text(
            "Regular list prices. No charge is taken today and nothing is activated.",
            color = muted,
        )

        PremiumPlanPreviewCatalog.plans.forEach { plan ->
            val selected = selectedInterval == plan.interval
            Surface(
                color = Color(0xFFFFFFFF),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth().clickable {
                    preview.select(plan)
                    selectedInterval = plan.interval
                },
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(plan.title, color = darkTeal, fontWeight = FontWeight.SemiBold)
                        Text(plan.priceLabel(), color = teal, fontWeight = FontWeight.Bold)
                    }
                    Text(plan.summary, color = muted)
                    Text(plan.contingentNote, color = muted)
                    if (selected) {
                        Text("Preview details · ${plan.cadence}", color = darkTeal)
                        plan.benefits.forEach { benefit -> Text("• $benefit", color = darkTeal) }
                    }
                    Text(
                        if (selected) "Selected" else "Preview details",
                        color = teal,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }

        Text("Not shown in preview: ${PremiumPlanPreviewCatalog.deferredToCheckout.joinToString(", ")}.", color = muted)

        Button(
            onClick = {
                preview.select(selectedInterval)
                preview.payNow()
                dialogVisible = true
            },
            colors = ButtonDefaults.buttonColors(containerColor = teal),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Pay now")
        }
        Text("Free access, safety alerts and support stay available without purchase.", color = muted)
    }

    if (dialogVisible) {
        ComingSoonOverlay(onDismiss = {
            preview.dismissComingSoon()
            dialogVisible = false
        })
    }
}

/** A visible, dismissible, payment-free modal matching the new Figma release preview. */
@Composable
fun ComingSoonOverlay(onDismiss: () -> Unit) {
    val deepTeal = Color(0xFF164950)
    val warmIvory = Color(0xFFFFF9F0)
    val softMint = Color(0xFFE4F4ED)
    val textMuted = Color(0xFF526B6B)
    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(28.dp),
        containerColor = warmIvory,
        tonalElevation = 8.dp,
        icon = {
            Box(
                modifier = Modifier.size(76.dp)
                    .background(softMint, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("✦", fontSize = 38.sp, color = deepTeal)
            }
        },
        title = {
            Text(
                "Coming Soon",
                fontSize = 23.sp,
                fontWeight = FontWeight.Bold,
                color = deepTeal,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    "Our premium plans are getting their finishing touches.",
                    color = deepTeal,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    "Purchases are not available yet. No payment has been taken and no subscription has been activated.",
                    color = textMuted,
                )
                Surface(color = softMint, shape = RoundedCornerShape(12.dp)) {
                    Text(
                        "YOUR FREE ACCESS CONTINUES UNCHANGED",
                        modifier = Modifier.padding(14.dp),
                        color = deepTeal,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
                Text(
                    "When purchases open, we will show the verified price and any eligible offer before you decide.",
                    color = textMuted,
                    fontSize = 13.sp,
                )
            }
        },
        confirmButton = {
            Button(
                onClick = onDismiss,
                colors = ButtonDefaults.buttonColors(containerColor = deepTeal),
            ) {
                Text("Got it — continue free")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Close") }
        },
    )
}
