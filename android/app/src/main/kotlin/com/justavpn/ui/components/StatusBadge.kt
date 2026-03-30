package com.justavpn.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.justavpn.data.ConnectionState

@Composable
fun StatusBadge(state: ConnectionState) {
    val (color, label) = when (state) {
        is ConnectionState.Connected -> Color(0xFF4CAF50) to "Protected"
        is ConnectionState.Connecting -> Color(0xFFFFC107) to "Connecting"
        is ConnectionState.Disconnecting -> Color(0xFFFFC107) to "Disconnecting"
        is ConnectionState.Paused -> Color(0xFFFF9800) to "Paused"
        is ConnectionState.Error -> Color(0xFFF44336) to "Error"
        is ConnectionState.Disconnected -> Color(0xFF9E9E9E) to "Unprotected"
    }

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = color
        )
    }
}
