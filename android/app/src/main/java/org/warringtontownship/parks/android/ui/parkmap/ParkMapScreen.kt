package org.warringtontownship.parks.android.ui.parkmap

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.warringtontownship.parks.android.ui.common.LandmarkBottomSheet
import org.warringtontownship.parks.android.ui.common.TrailMap
import org.warringtontownship.parks.android.ui.common.TrailMapMarker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParkMapScreen(
    viewModel: ParkMapViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var selectedMarkerId by remember { mutableStateOf<Int?>(null) }
    var openedByBeacon by remember { mutableStateOf(false) }

    DisposableEffect(viewModel) {
        viewModel.onScreenActive()
        onDispose { viewModel.onScreenInactive() }
    }

    val bluetoothPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = { },
    )

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            bluetoothPermissionLauncher.launch(Manifest.permission.BLUETOOTH_SCAN)
        }
    }

    LaunchedEffect(Unit) {
        viewModel.navigationEvent.collect { markerId ->
            openedByBeacon = true
            selectedMarkerId = markerId
        }
    }

    TrailMap(
        routes = uiState.routes,
        markers = uiState.markers.map {
            TrailMapMarker(it.id, it.title, it.category, it.latitude, it.longitude)
        },
        boundsCoordinates = uiState.boundary,
        modifier = Modifier.fillMaxSize(),
        onMarkerClick = { openedByBeacon = false; selectedMarkerId = it },
        // This map covers both locations at once, so zoomed out it shows one pin per
        // trailhead instead of 40 overlapping landmarks.
        collapseMarkersWhenZoomedOut = true,
    )

    if (selectedMarkerId != null) {
        val landmark = viewModel.getLandmarkForMarker(selectedMarkerId!!)
        val announcement = if (openedByBeacon) {
            viewModel.announcementTextFor(selectedMarkerId!!)?.let { "${it.title}. ${it.body}" }
        } else {
            null
        }
        LandmarkBottomSheet(
            landmark = landmark,
            imageUrl = landmark?.let { viewModel.imageUrlFor(it) },
            announceOnOpen = announcement,
            onDismiss = { selectedMarkerId = null },
        )
    }
}
