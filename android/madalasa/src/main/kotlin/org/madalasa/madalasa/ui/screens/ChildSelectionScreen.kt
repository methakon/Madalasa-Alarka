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
    onPairNewChild: () -> Unit
) {
    var generatedCode by remember { mutableStateOf<String?>(null) }

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

        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(uiState.children) { child ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onChildSelected(child.id) },
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

        Button(
            onClick = onPairNewChild,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = ThemeCTokens.DeepIndigo)
        ) {
            Text("+ Pair New Companion Device", color = ThemeCTokens.Parchment)
        }
    }
}
