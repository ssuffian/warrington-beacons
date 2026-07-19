package org.warringtontownship.us202.android.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Hiking
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.vector.ImageVector

sealed class BottomNavItem(
    val label: String,
    val icon: ImageVector,
    val graphRoute: String,
) {
    data object ParkMap : BottomNavItem(
        label = "Park Map",
        icon = Icons.Default.Map,
        graphRoute = NavRoutes.PARK_MAP_GRAPH,
    )

    data object TrailTours : BottomNavItem(
        label = "Trail Tours",
        icon = Icons.Default.Hiking,
        graphRoute = NavRoutes.TRAIL_TOURS_GRAPH,
    )

    data object About : BottomNavItem(
        label = "About",
        icon = Icons.Default.Info,
        graphRoute = NavRoutes.ABOUT_GRAPH,
    )

    data object Settings : BottomNavItem(
        label = "Settings",
        icon = Icons.Default.Settings,
        graphRoute = NavRoutes.SETTINGS_GRAPH,
    )

    companion object {
        val items = listOf(ParkMap, TrailTours, About, Settings)
    }
}
