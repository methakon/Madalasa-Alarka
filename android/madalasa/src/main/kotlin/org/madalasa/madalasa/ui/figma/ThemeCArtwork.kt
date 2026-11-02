package org.madalasa.madalasa.ui.figma

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

/** Native vector illustration derived from Theme C's approved palette.
 * Decorative only: nothing here implies a real location, verified pairing or consent.
 * The more detailed Figma AI raster art remains a separate design asset.
 */
@Composable
internal fun ThemeCArtwork(id: String, modifier: Modifier = Modifier) {
    val ink = Color(0xFF233F69)
    val teal = Color(0xFF28756C)
    val red = Color(0xFFB73527)
    val gold = Color(0xFFE7B44A)
    val leaf = Color(0xFF5B784B)
    val privacy = id.contains("permission", true) || id in setOf("C-05","C-06","C-07","P-27")
    val journey = id in setOf("P-05","P-06","P-07","P-08","P-14","P-15","P-16","C-12","C-13")
    val support = id in setOf("P-40","P-41","P-42","P-43","P-44","P-45")
    Canvas(modifier = modifier.width(104.dp).height(94.dp)) {
        val sx = size.width / 104f; val sy = size.height / 94f
        fun xy(x: Float,y:Float)=Offset(x*sx,y*sy)
        fun dot(x:Float,y:Float,r:Float,c:Color)=drawCircle(c,r*sx,xy(x,y))
        drawCircle(Color(0xFFF5DCA7),42f*sx,xy(54f,47f))
        val shield=Path().apply { moveTo(52*sx,7*sy); cubicTo(70*sx,21*sy,82*sx,15*sy,82*sx,42*sy); cubicTo(82*sx,67*sy,65*sx,79*sy,52*sx,86*sy); cubicTo(39*sx,79*sy,22*sx,67*sy,22*sx,42*sy); cubicTo(22*sx,15*sy,34*sx,21*sy,52*sx,7*sy); close() }
        drawPath(shield,Color(0xFFFFF7E7))
        drawPath(shield,gold,style=Stroke(3f*sx))
        if(journey) {
            dot(43f,43f,16f,teal);dot(43f,43f,7f,Color.White)
            val path=Path().apply { moveTo(45*sx,63*sy); quadraticTo(72*sx,71*sy,75*sx,47*sy) }
            drawPath(path,red,style=Stroke(3f*sx))
            dot(75f,37f,10f,red);dot(75f,37f,3f,Color.White)
        } else if(privacy){
            drawRoundRect(ink,topLeft=xy(39f,39f),size=Size(29*sx,23*sy),cornerRadius=androidx.compose.ui.geometry.CornerRadius(5*sx))
            drawArc(ink,180f,180f,false,topLeft=xy(45f,27f),size=Size(17*sx,27*sy),style=Stroke(4*sx))
            dot(53f,50f,3f,gold)
        } else if(support) {
            drawRoundRect(teal,topLeft=xy(34f,33f),size=Size(39*sx,28*sy),cornerRadius=androidx.compose.ui.geometry.CornerRadius(8*sx))
            dot(44f,46f,2f,Color.White);dot(54f,46f,2f,Color.White);dot(64f,46f,2f,Color.White)
        } else {
            dot(43f,35f,11f,ink); dot(64f,41f,9f,teal)
            drawOval(ink,topLeft=xy(28f,48f),size=Size(34*sx,24*sy))
            drawOval(teal,topLeft=xy(54f,52f),size=Size(22*sx,18*sy))
            dot(75f,29f,5f,red)
        }
        dot(18f,71f,6f,leaf);dot(88f,75f,7f,leaf)
    }
}
