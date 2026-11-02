package org.madalasa.madalasa.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.madalasa.ui.theme.ThemeCTokens

data class StorySlide(
    val title: String,
    val description: String
)

private val StorySlides = listOf(
    StorySlide("A Mother's Wisdom", "Madalasa raised her sons with thoughtful guidance, encouraging understanding beyond fear and pride."),
    StorySlide("Alarka's Responsibility", "For her youngest son Alarka, she also taught the duties of family life and just leadership."),
    StorySlide("The Ring of Counsel", "When Alarka became king, Madalasa entrusted him with a ring holding counsel for difficult times."),
    StorySlide("Remembering Her Words", "In adversity, Alarka remembered his mother's words and read the message inside the ring."),
    StorySlide("The Path to Wisdom", "Guided by that counsel, Alarka sought insight from Dattatreya and reconsidered the nature of his difficulties.")
)

@Composable
fun OnboardingScreen(
    onFinished: () -> Unit,
    onSkip: () -> Unit
) {
    var currentSlide by remember { mutableIntStateOf(0) }
    val slide = StorySlides[currentSlide]

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ThemeCTokens.Parchment)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Madālasā",
                style = MaterialTheme.typography.titleMedium,
                color = ThemeCTokens.DeepIndigo,
                fontWeight = FontWeight.Bold
            )
            OutlinedButton(onClick = onSkip) {
                Text("Skip", color = ThemeCTokens.Ink)
            }
        }

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp),
            colors = CardDefaults.cardColors(containerColor = ThemeCTokens.PaleWarmSurface),
            shape = RoundedCornerShape(16.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "${currentSlide + 1} / ${StorySlides.size}",
                    fontSize = 12.sp,
                    color = ThemeCTokens.MutedText,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = slide.title,
                    fontSize = 20.sp,
                    color = ThemeCTokens.Ink,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = slide.description,
                    fontSize = 15.sp,
                    color = ThemeCTokens.Ink,
                    textAlign = TextAlign.Center,
                    lineHeight = 22.sp
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            if (currentSlide > 0) {
                OutlinedButton(onClick = { currentSlide-- }) {
                    Text("Back", color = ThemeCTokens.Ink)
                }
            } else {
                Box(modifier = Modifier)
            }

            Button(
                onClick = {
                    if (currentSlide < StorySlides.size - 1) {
                        currentSlide++
                    } else {
                        onFinished()
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = ThemeCTokens.DeepIndigo)
            ) {
                Text(
                    if (currentSlide < StorySlides.size - 1) "Next" else "Get Started",
                    color = ThemeCTokens.Parchment
                )
            }
        }
    }
}
