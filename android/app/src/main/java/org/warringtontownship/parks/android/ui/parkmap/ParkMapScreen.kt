package org.warringtontownship.parks.android.ui.parkmap

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
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
    val announcementsEnabled by viewModel.announcementsEnabled.collectAsStateWithLifecycle()
    val statusMessage by viewModel.statusMessage.collectAsStateWithLifecycle()
    var selectedMarkerId by remember { mutableStateOf<Int?>(null) }
    var openedByBeacon by remember { mutableStateOf(false) }

    DisposableEffect(viewModel) {
        viewModel.onScreenActive()
        onDispose { viewModel.onScreenInactive() }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
        onResult = { },
    )

    LaunchedEffect(Unit) {
        val wanted = mutableListOf(Manifest.permission.BLUETOOTH_SCAN)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            wanted += Manifest.permission.POST_NOTIFICATIONS
        }
        permissionLauncher.launch(wanted.toTypedArray())
    }

    LaunchedEffect(Unit) {
        viewModel.navigationEvent.collect { markerId ->
            openedByBeacon = true
            selectedMarkerId = markerId
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .semantics(mergeDescendants = true) { stateDescription = statusMessage },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Announce nearby landmarks",
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = announcementsEnabled,
                onCheckedChange = { viewModel.setAnnouncementsEnabled(it) },
            )
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
    }

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
