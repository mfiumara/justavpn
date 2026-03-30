package com.justavpn.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.justavpn.data.ConnectionState
import com.justavpn.ui.components.PauseTimerPicker
import com.justavpn.ui.components.StatusBadge
import com.justavpn.viewmodel.VPNViewModel
import java.time.Duration
import java.time.Instant

@Composable
fun ConnectionScreen(viewModel: VPNViewModel = viewModel()) {
    val state by viewModel.connectionState.collectAsStateWithLifecycle()
    val activeServer by viewModel.activeServer.collectAsStateWithLifecycle()
    var showPausePicker by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(modifier = Modifier.weight(1f))

        StatusBadge(state = state)

        Spacer(modifier = Modifier.height(24.dp))

        // Server info
        activeServer?.let { server ->
            Text(server.name, style = MaterialTheme.typography.headlineSmall)
            Text(
                server.endpoint,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } ?: run {
            Text("No server configured", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Duration
        if (state is ConnectionState.Connected) {
            val since = (state as ConnectionState.Connected).since
            var elapsed by remember { mutableLongStateOf(0L) }
            LaunchedEffect(since) {
                while (true) {
                    elapsed = Duration.between(since, Instant.now()).seconds
                    kotlinx.coroutines.delay(1000)
                }
            }
            val hours = elapsed / 3600
            val minutes = (elapsed % 3600) / 60
            val secs = elapsed % 60
            Text(
                "%02d:%02d:%02d".format(hours, minutes, secs),
                style = MaterialTheme.typography.titleMedium,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Connect button
        val buttonColor = when (state) {
            is ConnectionState.Connected -> Color(0xFF4CAF50)
            is ConnectionState.Connecting, is ConnectionState.Disconnecting -> Color(0xFFFFC107)
            is ConnectionState.Paused -> Color(0xFFFF9800)
            is ConnectionState.Error -> Color(0xFFF44336)
            is ConnectionState.Disconnected -> Color(0xFF9E9E9E)
        }

        Button(
            onClick = { viewModel.toggle() },
            modifier = Modifier.size(120.dp),
            shape = CircleShape,
            enabled = activeServer != null,
            colors = ButtonDefaults.buttonColors(containerColor = buttonColor)
        ) {
            Text(
                when (state) {
                    is ConnectionState.Connected -> "ON"
                    is ConnectionState.Connecting -> "..."
                    else -> "OFF"
                },
                fontSize = 24.sp,
                color = Color.White
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            state.statusText,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.weight(1f))

        // Pause / Resume buttons
        if (state is ConnectionState.Connected) {
            OutlinedButton(onClick = { showPausePicker = true }) {
                Text("Pause VPN")
            }
        }

        if (state is ConnectionState.Paused) {
            Button(onClick = { viewModel.toggle() }) {
                Text("Resume Now")
            }
        }
    }

    if (showPausePicker) {
        PauseTimerPicker(
            onSelect = { seconds ->
                viewModel.pause(seconds)
                showPausePicker = false
            },
            onDismiss = { showPausePicker = false }
        )
    }
}
