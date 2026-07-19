package org.warringtontownship.us202.android.ui.common

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import org.warringtontownship.us202.android.data.model.Landmark

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LandmarkBottomSheet(
    landmark: Landmark?,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val simplifiedText = remember {
        context.getSharedPreferences("us202_prefs", android.content.Context.MODE_PRIVATE)
            .getBoolean("simplified_text", false)
    }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            if (landmark != null) {
                AsyncImage(
                    model = "https://ssuffian.github.io/warrington-beacons/us-202/images/${landmark.imageName}.jpg",
                    contentDescription = landmark.name,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f),
                )

                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = landmark.name,
                        style = MaterialTheme.typography.headlineMedium,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = if (landmark.category == "Trail") "Trailhead" else "Landmark",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = if (simplifiedText) landmark.description else landmark.longDescription,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            } else {
                Text(
                    text = "Location not found.",
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(16.dp),
                )
            }
        }
    }
}
