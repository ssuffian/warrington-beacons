package org.warringtontownship.parks.android.ui.common

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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import org.warringtontownship.parks.android.data.model.Landmark

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LandmarkBottomSheet(
    landmark: Landmark?,
    imageUrl: String?,
    announceOnOpen: String? = null,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val simplifiedText = remember {
        context.getSharedPreferences("warrington_prefs", android.content.Context.MODE_PRIVATE)
            .getBoolean("simplified_text", false)
    }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // A beacon opened this sheet, so nothing the user did will make TalkBack read
    // it. Announce explicitly; a tapped sheet is already narrated by the tap.
    LaunchedEffect(announceOnOpen) {
        if (announceOnOpen != null) {
            view.announceForAccessibility(announceOnOpen)
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            if (landmark != null) {
                AsyncImage(
                    model = imageUrl,
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
