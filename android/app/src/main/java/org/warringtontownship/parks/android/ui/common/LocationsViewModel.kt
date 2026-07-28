package org.warringtontownship.parks.android.ui.common

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import android.util.Log
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject

/** Supplies the location names and addresses shown on the Welcome and About screens. */
@HiltViewModel
class LocationsViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
) : ViewModel() {

    private val _locations = MutableStateFlow<List<Location>>(emptyList())
    val locations: StateFlow<List<Location>> = _locations.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                trailRepository.loadData()
                _locations.value = trailRepository.getLocations()
            } catch (e: Exception) {
                // Offline on first launch: the screen renders without the address block.
                Log.e("LocationsVM", "Unable to load locations", e)
            }
        }
    }
}
