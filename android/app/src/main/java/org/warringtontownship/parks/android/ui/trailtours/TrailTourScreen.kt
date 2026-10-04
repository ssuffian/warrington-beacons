package org.warringtontownship.parks.android.ui.trailtours

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.ui.common.LandmarkBottomSheet
import org.warringtontownship.parks.android.ui.common.TrailMap
import org.warringtontownship.parks.android.ui.common.TrailMapMarker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrailTourScreen(
    trailId: String,
    reverse: Boolean,
    startLandmarkId: String?,
    onBack: () -> Unit,
    viewModel: TrailToursViewModel,
) {
    val trail = viewModel.getTrailById(trailId)

    if (trail == null) {
        TourMessageScreen(message = "Trail not found.", onBack = onBack)
        return
    }

    val stops = remember(trail) { tourStops(trail) }

    if (stops.isEmpty()) {
        TourMessageScreen(message = "This trail has no tour stops.", onBack = onBack)
        return
    }
    var currentIndex by remember {
        // A beacon is matched to a place by its beaconMinor, never by the place ID.
        val beaconLandmarkId = viewModel.getClosestBeaconLandmarkId()
        val beaconIndex = if (beaconLandmarkId != null) stops.indexOfFirst { it.landmarkId == beaconLandmarkId } else -1
        mutableIntStateOf(if (beaconIndex >= 0) beaconIndex else initialTourIndex(stops, startLandmarkId, reverse))
    }
    var sheetLandmarkId by remember { mutableStateOf<String?>(null) }
    // Only a beacon-opened sheet is announced. A Previous/Next or marker tap is
    // already narrated by TalkBack as the user's own action; speaking it again
    // would double up.
    var sheetOpenedByBeacon by remember { mutableStateOf(false) }
    var beaconZoomPosition by remember { mutableStateOf<Coordinates?>(null) }

    DisposableEffect(viewModel) {
        viewModel.onTourScreenActive()
        onDispose { viewModel.onTourScreenInactive() }
    }

    LaunchedEffect(Unit) {
        // Check if a beacon is already in range when the screen starts
        val initialBeacon = viewModel.getClosestBeaconLandmarkId()
        if (initialBeacon != null) {
            val stopIndex = stops.indexOfFirst { it.landmarkId == initialBeacon }
            if (stopIndex >= 0) {
                currentIndex = stopIndex
                sheetOpenedByBeacon = true
                sheetLandmarkId = initialBeacon
                val stop = stops[stopIndex]
                beaconZoomPosition = Coordinates(stop.latitude, stop.longitude)
            }
        }
        // Then collect future beacon changes
        viewModel.beaconEvent.collect { landmarkId ->
            val stopIndex = stops.indexOfFirst { it.landmarkId == landmarkId }
            if (stopIndex >= 0) {
                currentIndex = stopIndex
                sheetOpenedByBeacon = true
                sheetLandmarkId = landmarkId
                val stop = stops[stopIndex]
                beaconZoomPosition = Coordinates(stop.latitude, stop.longitude)
            }
        }
    }

    val currentStop = stops[currentIndex.coerceIn(0, stops.size - 1)]
    val currentLandmark = currentStop.landmarkId?.let { viewModel.getLandmarkById(it) }
    val nextTitle = when (
        val next = nextInTour(
            stopCount = stops.size,
            currentIndex = currentIndex.coerceIn(0, stops.size - 1),
            reverse = reverse,
            hasStart = trail.start != null,
            hasEnd = trail.end != null,
        )
    ) {
        is TourNext.Stop -> stops[next.index].landmarkId?.let { viewModel.getLandmarkById(it) }?.name
        TourNext.TrailStart -> TRAIL_START_TITLE
        TourNext.TrailEnd -> TRAIL_END_TITLE
    }
    // Directions from the trail start lead forward to the first stop; from the trail
    // end they lead back to the last stop.
    val approachDirections = when {
        !reverse && currentIndex == 0 ->
            trail.start?.directions?.takeIf { it.isNotBlank() }?.let { "From the trail start: $it" }
        reverse && currentIndex == stops.size - 1 ->
            trail.end?.directions?.takeIf { it.isNotBlank() }?.let { "From the trail end: $it" }
        else -> null
    }

    val coords = trail.boundaryCoordinates.map {
        Coordinates(it.latitude, it.longitude)
    }
    val markerList = stops.mapNotNull { stop ->
        val landmarkId = stop.landmarkId ?: return@mapNotNull null
        val lm = viewModel.getLandmarkById(landmarkId)
        TrailMapMarker(
            id = landmarkId,
            title = lm?.name ?: "Stop",
            category = lm?.category ?: "",
            latitude = stop.latitude,
            longitude = stop.longitude,
        )
    } + endpointMarkers(trail)
    val bounds = viewModel.getBoundsForTrail(trailId)

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
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 300.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                Text(
                    text = "Current: ${currentLandmark?.name ?: "Unknown"}",
                    style = MaterialTheme.typography.titleLarge,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Next: ${nextTitle ?: "Unknown"}",
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
                if (approachDirections != null) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = approachDirections,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
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
                            sheetOpenedByBeacon = false
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
                            sheetOpenedByBeacon = false
                            sheetLandmarkId = stops[newIndex].landmarkId
                        },
                    ) {
                        Text("Next")
                    }
                }
            }

            TrailMap(
                routes = listOf(coords),
                markers = markerList,
                boundsCoordinates = bounds,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                focusPosition = Coordinates(currentStop.latitude, currentStop.longitude),
                centerZoomPosition = beaconZoomPosition,
                highlightedMarkerId = currentStop.landmarkId,
                onMarkerClick = { landmarkId ->
                    sheetOpenedByBeacon = false
                    sheetLandmarkId = landmarkId
                },
            )
        }
    }

    val openSheetLandmarkId = sheetLandmarkId
    if (openSheetLandmarkId != null) {
        val landmark = viewModel.getLandmarkById(openSheetLandmarkId)
        val announcement = if (sheetOpenedByBeacon) {
            viewModel.announcementTextFor(openSheetLandmarkId)?.let { "${it.title}. ${it.body}" }
        } else {
            null
        }
        LandmarkBottomSheet(
            landmark = landmark,
            imageUrl = landmark?.let { viewModel.imageUrlFor(it) },
            announceOnOpen = announcement,
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
