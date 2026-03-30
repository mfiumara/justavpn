package com.justavpn.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.justavpn.util.PauseDuration

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PauseTimerPicker(
    onSelect: (Int) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .padding(24.dp)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Pause VPN for", style = MaterialTheme.typography.titleMedium)

            PauseDuration.entries.forEach { duration ->
                OutlinedButton(
                    onClick = { onSelect(duration.seconds) },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(duration.label)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
