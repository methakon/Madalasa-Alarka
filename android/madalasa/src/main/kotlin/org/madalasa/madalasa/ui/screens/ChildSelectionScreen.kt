package org.madalasa.madalasa.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.madalasa.ui.theme.ThemeCTokens
import org.madalasa.madalasa.ui.viewmodel.ParentUiState

@Composable
fun ChildSelectionScreen(
    uiState: ParentUiState,
    onChildSelected: (String) -> Unit,
    onPairNewChild: (onCode: (String) -> Unit, onError: (String) -> Unit) -> Unit,
    onViewPairedDevice: (onStatus: (String) -> Unit) -> Unit = {},
    onRefreshServiceStatus: () -> Unit = {},
    onExplorePremiumPlans: () -> Unit = {},
    onRegisterChild: (familyLabel: String, childAlias: String, onResult: (String) -> Unit) -> Unit = { _, _, _ -> },
    syntheticPreview: Boolean = false
) {
    var generatedCode by remember { mutableStateOf<String?>(null) }
    var familyLabel by remember { mutableStateOf("") }
    var childAlias by remember { mutableStateOf("") }
    var registrationMessage by remember { mutableStateOf("") }
    val availableChildren=uiState.children.filter { it.freeServiceState == "ADMITTED" }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ThemeCTokens.Parchment)
            .padding(20.dp)
    ) {
        Text(
            text = "Select Child Profile",
            style = MaterialTheme.typography.titleLarge,
            color = ThemeCTokens.DeepIndigo,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "Each child operates under independent parental authority and scope.",
            style = MaterialTheme.typography.bodySmall,
            color = ThemeCTokens.MutedText
        )
        Spacer(modifier = Modifier.height(16.dp))
        if (syntheticPreview) {
            Text("SYNTHETIC DEVELOPMENT PREVIEW · NO LIVE CHILD MONITORING",
                color = ThemeCTokens.Vermilion,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp)
            Spacer(modifier = Modifier.height(12.dp))
        }

        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(uiState.children) { child ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = child.freeServiceState == "ADMITTED") {
                            onChildSelected(child.id)
                        },
                    colors = CardDefaults.cardColors(
                        containerColor = if (child.id == uiState.selectedChildId)
                            ThemeCTokens.PaleWarmSurface
                        else
                            ThemeCTokens.PaleWarmSurface.copy(alpha = 0.7f)
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = child.alias,
                                fontWeight = FontWeight.SemiBold,
                                color = ThemeCTokens.Ink,
                                fontSize = 16.sp
                            )
                            Text(
                                text = "ID: ${child.id.take(8)}...",
                                color = ThemeCTokens.MutedText,
                                fontSize = 12.sp
                            )
                            if (child.freeServiceState == "WAITLISTED") {
                                Text(
                                    text = "Service queue" +
                                        (child.queuePosition?.let { " · Position $it" } ?: ""),
                                    color = ThemeCTokens.Vermilion,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Your child is in the service queue. We'll allocate a slot as soon as one becomes available. Free services have not started.",
                                    color = ThemeCTokens.MutedText,
                                    fontSize = 12.sp
                                )
                            } else if (child.freeServiceState == "ADMITTED") {
                                Text("Free slot allocated · Consent and device setup required",
                                    color = ThemeCTokens.Teal,fontSize=12.sp)
                            } else {
                                Text(
                                    "Service status not verified. Refresh before proceeding.",
                                    color = ThemeCTokens.Vermilion,
                                    fontSize = 12.sp
                                )
                            }
                        }
                        if (child.id == uiState.selectedChildId) {
                            Text(
                                text = "Active",
                                color = ThemeCTokens.Teal,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onExplorePremiumPlans, modifier = Modifier.fillMaxWidth()) {
            Text("Explore future premium plans · ₹99 / ₹999")
        }
        Text("Preview only: Pay now shows Coming Soon. The free queue cannot be bypassed.",
            color = ThemeCTokens.MutedText, fontSize = 12.sp)
        Spacer(modifier = Modifier.height(12.dp))

        Text("Register a child",fontWeight=FontWeight.Bold,color=ThemeCTokens.DeepIndigo)
        if (uiState.profile?.familyIds.isNullOrEmpty()) {
            OutlinedTextField(
                value=familyLabel,onValueChange={ familyLabel=it.take(100) },
                label={ Text("Family name") },singleLine=true,
                modifier=Modifier.fillMaxWidth()
            )
        }
        OutlinedTextField(
            value=childAlias,onValueChange={ childAlias=it.take(80) },
            label={ Text("Child nickname") },singleLine=true,
            modifier=Modifier.fillMaxWidth()
        )
        Button(
            onClick={
                registrationMessage="Submitting registration…"
                onRegisterChild(familyLabel.trim(),childAlias.trim()) {
                    registrationMessage=it
                }
            },
            enabled=childAlias.isNotBlank() &&
                (!uiState.profile?.familyIds.isNullOrEmpty() || familyLabel.isNotBlank()),
            modifier=Modifier.fillMaxWidth()
        ) {
            Text("Complete child registration")
        }
        if (registrationMessage.isNotBlank()) {
            Text(registrationMessage,color=ThemeCTokens.MutedText,fontSize=12.sp)
        }
        Spacer(modifier = Modifier.height(8.dp))
        if (uiState.children.any { it.freeServiceState != "ADMITTED" }) {
            Button(onClick = onRefreshServiceStatus, modifier = Modifier.fillMaxWidth()) {
                Text("Refresh service queue status")
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
        Button(
            onClick = {
                generatedCode = null
                registrationMessage = ""
                onPairNewChild(
                    { code -> generatedCode = code },
                    { message -> registrationMessage = message }
                )
            },
            enabled=availableChildren.isNotEmpty(),
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = ThemeCTokens.DeepIndigo)
        ) {
            Text("+ Pair New Companion Device", color = ThemeCTokens.Parchment)
        }
        if (availableChildren.isNotEmpty()) {
            Button(
                onClick = { onViewPairedDevice { registrationMessage = it } },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("View paired child device")
            }
        }
        if (generatedCode != null) {
            Text(
                "Parent-issued pairing code: ${generatedCode}",
                fontWeight = FontWeight.Bold,
                color = ThemeCTokens.DeepIndigo
            )
            Text(
                "Enter this one-time code in Alarka on the child's phone. It expires shortly. Pairing alone does not start monitoring.",
                color = ThemeCTokens.MutedText,
                fontSize = 12.sp
            )
        }
    }
}
