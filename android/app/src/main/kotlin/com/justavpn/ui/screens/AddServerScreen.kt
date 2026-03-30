package com.justavpn.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.justavpn.data.ServerConfig
import com.justavpn.viewmodel.VPNViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddServerScreen(
    onDone: () -> Unit,
    viewModel: VPNViewModel = viewModel()
) {
    var name by remember { mutableStateOf("") }
    var configText by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Server") },
                navigationIcon = {
                    IconButton(onClick = onDone) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            val config = ServerConfig.fromWireGuardConfig(configText, name)
                            if (config == null) {
                                errorMessage = "Invalid WireGuard config"
                            } else {
                                viewModel.addServer(config)
                                onDone()
                            }
                        },
                        enabled = name.isNotBlank() && configText.isNotBlank()
                    ) {
                        Text("Add")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize()
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Server Name") },
                placeholder = { Text("e.g. My VPS") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Spacer(modifier = Modifier.height(16.dp))

            OutlinedTextField(
                value = configText,
                onValueChange = { configText = it; errorMessage = null },
                label = { Text("WireGuard Config") },
                placeholder = { Text("Paste the full client .conf file") },
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                minLines = 10
            )

            errorMessage?.let {
                Spacer(modifier = Modifier.height(8.dp))
                Text(it, color = MaterialTheme.colorScheme.error)
            }
        }
    }
}
