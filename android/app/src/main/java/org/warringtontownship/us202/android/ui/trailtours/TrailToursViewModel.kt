package org.warringtontownship.us202.android.ui.trailtours

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import org.warringtontownship.us202.android.beacon.BeaconScanner
import org.warringtontownship.us202.android.data.model.Trail
import org.warringtontownship.us202.android.data.repository.TrailRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import org.warringtontownship.us202.android.data.model.Coordinates
import org.warringtontownship.us202.android.data.model.Landmark
import javax.inject.Inject

data class TrailToursUiState(
    val trails: List<Trail> = emptyList(),
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

    private var beaconUuid: String? = null
    private var beaconMajorCode: Int? = null
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
                _uiState.value = TrailToursUiState(trails = trailRepository.getTrails())
                beaconUuid = trailRepository.getBeaconUUID()
                beaconMajorCode = trailRepository.getBeaconMajorCode()
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
        val uuid = beaconUuid ?: return
        val majorCode = beaconMajorCode ?: return
        beaconScanner.startScanning(SCAN_CONSUMER, uuid, majorCode)
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
    fun getBounds(): List<Coordinates> = trailRepository.getBoundary()
}
