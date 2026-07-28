package org.warringtontownship.parks.android.ui.trailtours

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.beacon.BeaconScanner
import org.warringtontownship.parks.android.data.model.Trail
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.repository.TrailRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.data.model.Landmark
import javax.inject.Inject

data class TrailToursUiState(
    val trailsByLocation: List<Pair<Location, List<Trail>>> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class TrailToursViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
    private val beaconScanner: BeaconScanner,
) : ViewModel() {

    private val _uiState = MutableStateFlow(TrailToursUiState())
    val uiState: StateFlow<TrailToursUiState> = _uiState.asStateFlow()

    private val _beaconEvent = MutableSharedFlow<Int>()
    val beaconEvent: SharedFlow<Int> = _beaconEvent.asSharedFlow()

    private var beaconRegions: List<BeaconRegion> = emptyList()
    private var scanning = false

    init {
        loadTrails()
        observeBeacons()
    }

    private fun loadTrails() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                trailRepository.loadData()
                _uiState.value = TrailToursUiState(
                    trailsByLocation = trailRepository.getTrailsByLocation(),
                )
                beaconRegions = trailRepository.getBeaconRegions()
                if (scanning) {
                    startScanningIfReady()
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message,
                )
            }
        }
    }

    private fun observeBeacons() {
        viewModelScope.launch {
            beaconScanner.closestBeaconMinorCode
                .filterNotNull()
                .collect { minorCode ->
                    _beaconEvent.emit(minorCode)
                }
        }
    }

    fun onTourScreenActive() {
        scanning = true
        startScanningIfReady()
    }

    fun onTourScreenInactive() {
        scanning = false
        beaconScanner.stopScanning(SCAN_CONSUMER)
    }

    private fun startScanningIfReady() {
        if (beaconRegions.isEmpty()) return
        beaconScanner.startScanning(SCAN_CONSUMER, beaconRegions)
    }

    override fun onCleared() {
        super.onCleared()
        beaconScanner.stopScanning(SCAN_CONSUMER)
    }

    private companion object {
        const val SCAN_CONSUMER = "trail_tour"
    }

    fun getClosestBeaconMinorCode(): Int? = beaconScanner.closestBeaconMinorCode.value
    fun getTrailById(id: Int): Trail? = trailRepository.getTrailById(id)
    fun getLandmarkById(id: Int): Landmark? = trailRepository.getLandmarkById(id)
    fun getBoundsForTrail(trailId: Int): List<Coordinates> = trailRepository.getBoundsForTrail(trailId)
    fun imageUrlFor(landmark: Landmark): String = trailRepository.imageUrlFor(landmark)
}
