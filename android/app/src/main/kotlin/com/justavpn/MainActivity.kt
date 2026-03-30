package com.justavpn

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.justavpn.ui.screens.ConnectionScreen
import com.justavpn.ui.screens.ServerListScreen
import com.justavpn.ui.screens.AddServerScreen
import com.justavpn.ui.screens.SettingsScreen
import com.justavpn.ui.theme.JustAVPNTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            JustAVPNTheme {
                JustAVPNNavigation()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JustAVPNNavigation() {
    val navController = rememberNavController()
    var selectedTab by remember { mutableIntStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = {
                        selectedTab = 0
                        navController.navigate("connection") {
                            popUpTo("connection") { inclusive = true }
                        }
                    },
                    icon = { Icon(painter = painterResource(android.R.drawable.ic_lock_lock), contentDescription = null) },
                    label = { Text("VPN") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = {
                        selectedTab = 1
                        navController.navigate("servers") {
                            popUpTo("connection")
                        }
                    },
                    icon = { Icon(painter = painterResource(android.R.drawable.ic_menu_mapmode), contentDescription = null) },
                    label = { Text("Servers") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = {
                        selectedTab = 2
                        navController.navigate("settings") {
                            popUpTo("connection")
                        }
                    },
                    icon = { Icon(painter = painterResource(android.R.drawable.ic_menu_preferences), contentDescription = null) },
                    label = { Text("Settings") }
                )
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = "connection",
            modifier = Modifier.padding(padding)
        ) {
            composable("connection") { ConnectionScreen() }
            composable("servers") {
                ServerListScreen(
                    onAddServer = { navController.navigate("add_server") }
                )
            }
            composable("add_server") {
                AddServerScreen(onDone = { navController.popBackStack() })
            }
            composable("settings") { SettingsScreen() }
        }
    }
}
