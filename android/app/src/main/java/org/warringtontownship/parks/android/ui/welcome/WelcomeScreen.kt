package org.warringtontownship.parks.android.ui.welcome

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.warringtontownship.parks.android.R
import org.warringtontownship.parks.android.ui.common.LocationsViewModel

@Composable
fun WelcomeScreen(
    onContinue: () -> Unit,
    viewModel: LocationsViewModel = hiltViewModel(),
) {
    val locations by viewModel.locations.collectAsStateWithLifecycle()
    // Scrollable, and the photo takes a fixed height rather than weight(1f): with two
    // locations' addresses the content exceeds a small screen at font scale 1.5 and up,
    // and a weighted image collapses to nothing before the Continue button gives way —
    // leaving no way past this screen at all.
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Spacer(modifier = Modifier.height(48.dp))
        Text(
            text = "Welcome to Warrington's parks and trails",
            style = MaterialTheme.typography.headlineLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(24.dp))
        Image(
            painter = painterResource(R.drawable.welcome_photo),
            contentDescription = "Park field",
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp),
            contentScale = ContentScale.Crop,
        )
        Spacer(modifier = Modifier.height(16.dp))
        locations.forEach { location ->
            Text(
                text = location.name,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = location.address,
                style = MaterialTheme.typography.bodyLarge,
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "This app is designed to enrich your trail experience by providing information about the trail.  As you move along the trail you will be alerted when there is a new point of interest nearby.",
            style = MaterialTheme.typography.bodyLarge,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "Trail Tours indicate the distances to the next point of interest on the trail.",
            style = MaterialTheme.typography.bodyLarge,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "We will ask your permission to display your location on the map as well as to detect nearby devices in order to sense trail beacons to identify landmarks you are close to.",
            style = MaterialTheme.typography.bodyLarge,
        )
        Spacer(modifier = Modifier.height(26.dp))
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Button(onClick = onContinue) {
                Text("Continue")
            }
        }
        Spacer(modifier = Modifier.height(24.dp))
    }
}
