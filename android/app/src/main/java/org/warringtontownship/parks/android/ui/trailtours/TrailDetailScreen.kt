package org.warringtontownship.parks.android.ui.trailtours

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.ui.common.TrailMap
import org.warringtontownship.parks.android.ui.common.TrailMapMarker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrailDetailScreen(
    trailId: String,
    onBack: () -> Unit,
    onStartTour: (String, Boolean, String?) -> Unit,
    viewModel: TrailToursViewModel = hiltViewModel(),
) {
    val trail = viewModel.getTrailById(trailId)
    val bounds = viewModel.getBoundsForTrail(trailId)
    var reverse by remember { mutableStateOf(false) }
    var selectedLandmarkId by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(trail?.name ?: "Trail Detail") },
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
                .verticalScroll(rememberScrollState())
        ) {
            if (trail != null) {
                val markers = tourStops(trail).mapNotNull { coord ->
                    val landmarkId = coord.landmarkId ?: return@mapNotNull null
                    val lm = viewModel.getLandmarkById(landmarkId)
                    TrailMapMarker(
                        id = landmarkId,
                        title = lm?.name ?: "Stop",
                        category = lm?.category ?: "",
                        latitude = coord.latitude,
                        longitude = coord.longitude,
                    )
                }
                // A chosen stop wins. Otherwise begin at the trail's own start (or end,
                // reversed) when the data has one, before guessing a "Trail" stop.
                val selectedMarker = selectedLandmarkId?.let { id ->
                    markers.firstOrNull { it.id == id }
                }
                val trailhead = if (selectedMarker == null) trailheadFor(trail, reverse) else null
                val startMarker = selectedMarker
                    ?: if (trailhead != null) null else {
                        markers.firstOrNull { it.category == "Trail" } ?: markers.firstOrNull()
                    }
                val startTitle = trailhead?.title ?: startMarker?.title

                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = trail.trailDistanceDescription,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "Direction",
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Button(
                            onClick = { reverse = false },
                            modifier = Modifier
                                .weight(1f)
                                .semantics { selected = !reverse },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (!reverse) MaterialTheme.colorScheme.primary else Color.Transparent,
                                contentColor = if (!reverse) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                            ),
                        ) {
                            Text("Forward")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(
                            onClick = { reverse = true },
                            modifier = Modifier
                                .weight(1f)
                                .semantics { selected = reverse },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (reverse) MaterialTheme.colorScheme.primary else Color.Transparent,
                                contentColor = if (reverse) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                            ),
                        ) {
                            Text("Reverse")
                        }
                    }
                    val startIndex = markers.indexOfFirst { it.id == startMarker?.id }
                    val headingToward = if (trailhead != null) {
                        // From the trail start the first stop is next; from the end, the last.
                        (if (reverse) markers.lastOrNull() else markers.firstOrNull())?.title
                    } else if (startIndex >= 0 && markers.size > 1) {
                        val nextIndex = if (reverse) {
                            if (startIndex > 0) startIndex - 1 else markers.size - 1
                        } else {
                            (startIndex + 1) % markers.size
                        }
                        markers[nextIndex].title
                    } else {
                        null
                    }
                    if (headingToward != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "You'll head toward $headingToward first.",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                    if (startTitle != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Starting at: $startTitle",
                            style = MaterialTheme.typography.bodyMedium,
                            textAlign = TextAlign.End,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "If you are not started at the trailhead, select the closest landmark as your starting point",
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }

                val coords = trail.boundaryCoordinates.map {
                    Coordinates(it.latitude, it.longitude)
                }

                TrailMap(
                    routes = listOf(coords),
                    markers = markers + endpointMarkers(trail),
                    boundsCoordinates = bounds,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(340.dp),
                    onMarkerClick = { landmarkId -> selectedLandmarkId = landmarkId },
                )

                Button(
                    onClick = {
                        // Null starts the tour from the trail start/end itself.
                        onStartTour(trailId, reverse, startMarker?.id)
                    },
                    enabled = markers.isNotEmpty(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                ) {
                    Text("Start Tour")
                }
            } else {
                Text(
                    text = "Trail not found.",
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(16.dp),
                )
            }
        }
    }
}
