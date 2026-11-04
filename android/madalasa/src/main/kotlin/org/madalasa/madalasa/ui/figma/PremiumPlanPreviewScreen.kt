package org.madalasa.madalasa.ui.figma

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
    var state by remember { mutableStateOf(PremiumPlanPreviewState()) }

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
            val selected = state.selectedPlan?.interval == plan.interval
            Surface(
                color = Color(0xFFFFFFFF),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth().clickable { state.select(plan) },
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(plan.title, color = darkTeal, fontWeight = FontWeight.SemiBold)
                        Text(plan.priceLabel(), color = teal, fontWeight = FontWeight.Bold)
                    }
                    Text(plan.summary, color = muted)
                    Text(plan.contingentNote, color = muted)
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
            onClick = { state.payNow() },
            colors = ButtonDefaults.buttonColors(containerColor = teal),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Pay now")
        }
        Text("Free access, safety alerts and support stay available without purchase.", color = muted)
    }

    if (state.comingSoonVisible) {
        ComingSoonOverlay(onDismiss = { state.dismissComingSoon() })
    }
}

/** Coming Soon overlay: both controls dismiss back to the unchanged free experience. */
@Composable
fun ComingSoonOverlay(onDismiss: () -> Unit) {
    val darkTeal = Color(0xFF164950)
    val muted = Color(0xFF6B8585)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Coming Soon", color = darkTeal, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Payments are not open yet.", color = darkTeal)
                Text("No charge has been taken and no subscription has been activated.", color = muted)
                Text("Your current free access is unchanged.", color = muted)
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Got it — continue free") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Close") } },
    )
}
