package org.warringtontownship.us202.android.ui.trailtours

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.warringtontownship.us202.android.data.model.Coordinates
import org.warringtontownship.us202.android.ui.common.LandmarkBottomSheet
import org.warringtontownship.us202.android.ui.common.TrailMap
import org.warringtontownship.us202.android.ui.common.TrailMapMarker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrailTourScreen(
    trailId: Int,
    reverse: Boolean,
    startLandmarkId: Int,
    onBack: () -> Unit,
    viewModel: TrailToursViewModel,
) {
    val trail = viewModel.getTrailById(trailId)

    if (trail == null) {
        TourMessageScreen(message = "Trail not found.", onBack = onBack)
        return
    }

    val stops = remember(trail) {
        trail.boundaryCoordinates.filter { it.landmarkId != null }
    }

    if (stops.isEmpty()) {
        TourMessageScreen(message = "This trail has no tour stops.", onBack = onBack)
        return
    }
    var currentIndex by remember {
        val beaconMinor = viewModel.getClosestBeaconMinorCode()
        val beaconIndex = if (beaconMinor != null) stops.indexOfFirst { it.landmarkId == beaconMinor } else -1
        val startIndex = if (beaconIndex >= 0) beaconIndex else stops.indexOfFirst { it.landmarkId == startLandmarkId }
        mutableIntStateOf(if (startIndex >= 0) startIndex else 0)
    }
    var sheetLandmarkId by remember { mutableStateOf<Int?>(null) }
    var beaconZoomPosition by remember { mutableStateOf<Coordinates?>(null) }

    DisposableEffect(viewModel) {
        viewModel.onTourScreenActive()
        onDispose { viewModel.onTourScreenInactive() }
    }

    LaunchedEffect(Unit) {
        // Check if a beacon is already in range when the screen starts
        val initialBeacon = viewModel.getClosestBeaconMinorCode()
        if (initialBeacon != null) {
            val stopIndex = stops.indexOfFirst { it.landmarkId == initialBeacon }
            if (stopIndex >= 0) {
                currentIndex = stopIndex
                sheetLandmarkId = initialBeacon
                val stop = stops[stopIndex]
                beaconZoomPosition = Coordinates(stop.latitude, stop.longitude)
            }
        }
        // Then collect future beacon changes
        viewModel.beaconEvent.collect { minorCode ->
            val stopIndex = stops.indexOfFirst { it.landmarkId == minorCode }
            if (stopIndex >= 0) {
                currentIndex = stopIndex
                sheetLandmarkId = minorCode
                val stop = stops[stopIndex]
                beaconZoomPosition = Coordinates(stop.latitude, stop.longitude)
            }
        }
    }

    val currentStop = stops[currentIndex]
    val nextIndex = if (reverse) {
        if (currentIndex > 0) currentIndex - 1 else stops.size - 1
    } else {
        (currentIndex + 1) % stops.size
    }
    val nextStop = stops[nextIndex]
    val currentLandmark = viewModel.getLandmarkById(currentStop.landmarkId!!)
    val nextLandmark = viewModel.getLandmarkById(nextStop.landmarkId!!)

    val coords = trail.boundaryCoordinates.map {
        Coordinates(it.latitude, it.longitude)
    }
    val markerList = stops.map { stop ->
        val lm = viewModel.getLandmarkById(stop.landmarkId!!)
        TrailMapMarker(
            id = stop.landmarkId,
            title = lm?.name ?: "Stop",
            category = lm?.category ?: "",
            latitude = stop.latitude,
            longitude = stop.longitude,
        )
    }
    val bounds = viewModel.getBounds()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(trail.name) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Current: ${currentLandmark?.name ?: "Unknown"}",
                    style = MaterialTheme.typography.titleLarge,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Next: ${nextLandmark?.name ?: "Unknown"}",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = if (reverse) {
                        currentStop.distanceToNextCounterClockwiseDescription ?: ""
                    } else {
                        currentStop.distanceToNextClockwiseDescription ?: ""
                    },
                    style = MaterialTheme.typography.bodyLarge,
                )
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    val previousEnabled = if (reverse) currentIndex < stops.size - 1 else currentIndex > 0
                    val nextEnabled = if (reverse) currentIndex > 0 else currentIndex < stops.size - 1
                    Button(
                        enabled = previousEnabled,
                        onClick = {
                            val newIndex = if (reverse) currentIndex + 1 else currentIndex - 1
                            currentIndex = newIndex
                            sheetLandmarkId = stops[newIndex].landmarkId
                        },
                    ) {
                        Text("Previous")
                    }
                    Button(
                        enabled = nextEnabled,
                        onClick = {
                            val newIndex = if (reverse) currentIndex - 1 else currentIndex + 1
                            currentIndex = newIndex
                            sheetLandmarkId = stops[newIndex].landmarkId
                        },
                    ) {
                        Text("Next")
                    }
                }
            }

            TrailMap(
                routeCoordinates = coords,
                markers = markerList,
                boundsCoordinates = bounds,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                focusPosition = Coordinates(currentStop.latitude, currentStop.longitude),
                centerZoomPosition = beaconZoomPosition,
                highlightedMarkerId = currentStop.landmarkId,
                onMarkerClick = { landmarkId -> sheetLandmarkId = landmarkId },
            )
        }
    }

    if (sheetLandmarkId != null) {
        val landmark = viewModel.getLandmarkById(sheetLandmarkId!!)
        LandmarkBottomSheet(
            landmark = landmark,
            onDismiss = { sheetLandmarkId = null },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TourMessageScreen(
    message: String,
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Trail Tour") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        }
    ) { padding ->
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(padding).padding(16.dp),
        )
    }
}
