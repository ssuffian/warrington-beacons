package org.warringtontownship.us202.android.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navigation
import org.warringtontownship.us202.android.ui.about.AboutScreen
import org.warringtontownship.us202.android.ui.parkmap.ParkMapScreen
import org.warringtontownship.us202.android.ui.parkmap.ParkMapViewModel
import org.warringtontownship.us202.android.ui.settings.SettingsScreen
import org.warringtontownship.us202.android.ui.trailtours.TrailDetailScreen
import org.warringtontownship.us202.android.ui.trailtours.TrailTourScreen
import org.warringtontownship.us202.android.ui.trailtours.TrailToursScreen
import org.warringtontownship.us202.android.ui.trailtours.TrailToursViewModel

@Composable
fun AppNavHost(
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    NavHost(
        navController = navController,
        startDestination = NavRoutes.PARK_MAP_GRAPH,
        modifier = modifier,
    ) {
        // Park Map tab
        navigation(
            startDestination = NavRoutes.PARK_MAP,
            route = NavRoutes.PARK_MAP_GRAPH,
        ) {
            composable(NavRoutes.PARK_MAP) { backStackEntry ->
                val graphEntry = remember(backStackEntry) {
                    navController.getBackStackEntry(NavRoutes.PARK_MAP_GRAPH)
                }
                val viewModel = hiltViewModel<ParkMapViewModel>(graphEntry)
                ParkMapScreen(
                    viewModel = viewModel,
                )
            }
        }

        // Trail Tours tab
        navigation(
            startDestination = NavRoutes.TRAIL_TOURS,
            route = NavRoutes.TRAIL_TOURS_GRAPH,
        ) {
            composable(NavRoutes.TRAIL_TOURS) { backStackEntry ->
                val graphEntry = remember(backStackEntry) {
                    navController.getBackStackEntry(NavRoutes.TRAIL_TOURS_GRAPH)
                }
                val viewModel = hiltViewModel<TrailToursViewModel>(graphEntry)
                TrailToursScreen(
                    onTrailClick = { trailId ->
                        navController.navigate(NavRoutes.trailDetail(trailId))
                    },
                    viewModel = viewModel,
                )
            }
            composable(
                route = NavRoutes.TRAIL_DETAIL,
                arguments = listOf(navArgument("trailId") { type = NavType.IntType }),
            ) { backStackEntry ->
                val graphEntry = remember(backStackEntry) {
                    navController.getBackStackEntry(NavRoutes.TRAIL_TOURS_GRAPH)
                }
                val viewModel = hiltViewModel<TrailToursViewModel>(graphEntry)
                TrailDetailScreen(
                    trailId = backStackEntry.arguments?.getInt("trailId") ?: 0,
                    onBack = { navController.popBackStack() },
                    onStartTour = { trailId, reverse, startLandmarkId ->
                        navController.navigate(NavRoutes.trailTour(trailId, reverse, startLandmarkId))
                    },
                    viewModel = viewModel,
                )
            }
            composable(
                route = NavRoutes.TRAIL_TOUR,
                arguments = listOf(
                    navArgument("trailId") { type = NavType.IntType },
                    navArgument("reverse") { type = NavType.BoolType },
                    navArgument("startLandmarkId") { type = NavType.IntType },
                ),
            ) { backStackEntry ->
                val graphEntry = remember(backStackEntry) {
                    navController.getBackStackEntry(NavRoutes.TRAIL_TOURS_GRAPH)
                }
                val viewModel = hiltViewModel<TrailToursViewModel>(graphEntry)
                TrailTourScreen(
                    trailId = backStackEntry.arguments?.getInt("trailId") ?: 0,
                    reverse = backStackEntry.arguments?.getBoolean("reverse") ?: false,
                    startLandmarkId = backStackEntry.arguments?.getInt("startLandmarkId") ?: 0,
                    onBack = { navController.popBackStack() },
                    viewModel = viewModel,
                )
            }
        }

        // About tab
        navigation(
            startDestination = NavRoutes.ABOUT,
            route = NavRoutes.ABOUT_GRAPH,
        ) {
            composable(NavRoutes.ABOUT) {
                AboutScreen()
            }
        }

        // Settings tab
        navigation(
            startDestination = NavRoutes.SETTINGS,
            route = NavRoutes.SETTINGS_GRAPH,
        ) {
            composable(NavRoutes.SETTINGS) {
                SettingsScreen()
            }
        }
    }
}
