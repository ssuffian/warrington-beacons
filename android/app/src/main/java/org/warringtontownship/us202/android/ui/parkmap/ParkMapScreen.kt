package org.warringtontownship.us202.android.ui.parkmap

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
import org.warringtontownship.us202.android.ui.common.LandmarkBottomSheet
import org.warringtontownship.us202.android.ui.common.TrailMap
import org.warringtontownship.us202.android.ui.common.TrailMapMarker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParkMapScreen(
    viewModel: ParkMapViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var selectedMarkerId by remember { mutableStateOf<Int?>(null) }

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
            selectedMarkerId = markerId
        }
    }

    TrailMap(
        routeCoordinates = uiState.coordinates,
        markers = uiState.markers.map {
            TrailMapMarker(it.id, it.title, it.category, it.latitude, it.longitude)
        },
        boundsCoordinates = uiState.boundary,
        modifier = Modifier.fillMaxSize(),
        onMarkerClick = { selectedMarkerId = it },
    )

    if (selectedMarkerId != null) {
        val landmark = viewModel.getLandmarkForMarker(selectedMarkerId!!)
        LandmarkBottomSheet(
            landmark = landmark,
            onDismiss = { selectedMarkerId = null },
        )
    }
}
