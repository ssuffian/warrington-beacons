package org.warringtontownship.us202.android.ui.welcome

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import org.warringtontownship.us202.android.R

@Composable
fun WelcomeScreen(
    onContinue: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Spacer(modifier = Modifier.height(48.dp))
        Text(
            text = "Welcome to the US-202 to Bradford Dam connector trail",
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
                .weight(1f),
            contentScale = ContentScale.Crop,
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Trailhead",
            style = MaterialTheme.typography.bodyLarge,
        )
        Text(
            text = "Stump Road across from 785",
            style = MaterialTheme.typography.bodyLarge,
        )
        Text(
            text = "Chalfont, PA 18914",
            style = MaterialTheme.typography.bodyLarge,
        )
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
