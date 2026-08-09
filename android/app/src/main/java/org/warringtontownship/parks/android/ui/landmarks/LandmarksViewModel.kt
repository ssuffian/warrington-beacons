package org.warringtontownship.parks.android.ui.landmarks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import android.util.Log
import org.warringtontownship.parks.android.data.model.Landmark
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject

data class LandmarksUiState(
    val landmarksByLocation: List<Pair<Location, List<Landmark>>> = emptyList(),
    val error: String? = null,
)

@HiltViewModel
class LandmarksViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(LandmarksUiState())
    val uiState: StateFlow<LandmarksUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                trailRepository.loadData()
                _uiState.value = LandmarksUiState(
                    landmarksByLocation = trailRepository.getLandmarksByLocation(),
                )
            } catch (e: Exception) {
                Log.e("LandmarksVM", "Unable to load landmarks", e)
                _uiState.value = LandmarksUiState(error = e.message)
            }
        }
    }

    fun imageUrlFor(landmark: Landmark): String = trailRepository.imageUrlFor(landmark)
}
