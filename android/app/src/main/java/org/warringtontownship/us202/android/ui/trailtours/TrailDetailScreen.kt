package org.warringtontownship.us202.android.ui.trailtours

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import org.warringtontownship.us202.android.data.model.Coordinates
import org.warringtontownship.us202.android.ui.common.TrailMap
import org.warringtontownship.us202.android.ui.common.TrailMapMarker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrailDetailScreen(
    trailId: Int,
    onBack: () -> Unit,
    onStartTour: (Int, Boolean, Int) -> Unit,
    viewModel: TrailToursViewModel = hiltViewModel(),
) {
    val trail = viewModel.getTrailById(trailId)
    val bounds = viewModel.getBounds()
    var reverse by remember { mutableStateOf(false) }
    var selectedLandmarkId by remember { mutableStateOf<Int?>(null) }

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
        ) {
            if (trail != null) {
                val markers = trail.boundaryCoordinates
                    .filter { it.landmarkId != null }
                    .map { coord ->
                        val lm = viewModel.getLandmarkById(coord.landmarkId!!)
                        TrailMapMarker(
                            id = coord.landmarkId,
                            title = lm?.name ?: "Stop",
                            category = lm?.category ?: "",
                            latitude = coord.latitude,
                            longitude = coord.longitude,
                        )
                    }
                val startMarker = selectedLandmarkId?.let { id ->
                    markers.firstOrNull { it.id == id }
                } ?: markers.firstOrNull { it.category == "Trail" }
                ?: markers.firstOrNull()

                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = trail.trailDistanceDescription,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = "DIRECTION:",
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        Spacer(modifier = Modifier.weight(1f))
                        Button(
                            onClick = { reverse = false },
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
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (reverse) MaterialTheme.colorScheme.primary else Color.Transparent,
                                contentColor = if (reverse) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                            ),
                        ) {
                            Text("Reverse")
                        }
                    }
                    if (startMarker != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Starting at: ${startMarker.title}",
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
                    routeCoordinates = coords,
                    markers = markers,
                    boundsCoordinates = bounds,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    onMarkerClick = { landmarkId -> selectedLandmarkId = landmarkId },
                )

                Column(modifier = Modifier.padding(top = 16.dp).fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally) {
                    Button(onClick = {
                        val startId = startMarker?.id ?: 0
                        onStartTour(trailId, reverse, startId)
                    }) {
                        Text("Start Tour")
                    }
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
