package org.warringtontownship.us202.android

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import org.warringtontownship.us202.android.navigation.AppNavHost
import org.warringtontownship.us202.android.navigation.BottomNavItem
import org.warringtontownship.us202.android.ui.theme.US202Theme
import org.warringtontownship.us202.android.ui.welcome.WelcomeScreen
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val prefs = remember {
                getSharedPreferences("us202_prefs", Context.MODE_PRIVATE)
            }
            var showWelcome by remember {
                mutableStateOf(!prefs.getBoolean("welcome_seen", false))
            }

            US202Theme {
                if (showWelcome) {
                    WelcomeScreen(
                        onContinue = {
                            prefs.edit().putBoolean("welcome_seen", true).apply()
                            showWelcome = false
                        }
                    )
                } else {
                    val navController = rememberNavController()
                    val navBackStackEntry by navController.currentBackStackEntryAsState()
                    val currentDestination = navBackStackEntry?.destination

                    Scaffold(
                        modifier = Modifier.fillMaxSize(),
                        bottomBar = {
                            NavigationBar {
                                BottomNavItem.items.forEach { item ->
                                    val selected = currentDestination?.hierarchy?.any {
                                        it.route == item.graphRoute
                                    } == true

                                    NavigationBarItem(
                                        selected = selected,
                                        onClick = {
                                            navController.navigate(item.graphRoute) {
                                                popUpTo(navController.graph.findStartDestination().id) {
                                                    saveState = true
                                                }
                                                launchSingleTop = true
                                                restoreState = true
                                            }
                                        },
                                        icon = { Icon(item.icon, contentDescription = item.label) },
                                        label = { Text(item.label) },
                                    )
                                }
                            }
                        }
                    ) { innerPadding ->
                        AppNavHost(
                            navController = navController,
                            modifier = Modifier.padding(innerPadding),
                        )
                    }
                }
            }
        }
    }
}
