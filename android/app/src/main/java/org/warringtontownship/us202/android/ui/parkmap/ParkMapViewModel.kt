package org.warringtontownship.us202.android.ui.parkmap

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import org.warringtontownship.us202.android.beacon.BeaconScanner
import org.warringtontownship.us202.android.data.repository.TrailRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import javax.inject.Inject
import android.util.Log
import org.warringtontownship.us202.android.data.model.Coordinates
import org.warringtontownship.us202.android.data.model.Landmark

data class MapMarker(
    val id: Int,
    val title: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
)

data class ParkMapUiState(
    val markers: List<MapMarker> = emptyList(),
    val coordinates: List<Coordinates> = emptyList(),
    val boundary: List<Coordinates> = emptyList(),
    val selectedMarker: MapMarker? = null,
)

@HiltViewModel
class ParkMapViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
    private val beaconScanner: BeaconScanner,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ParkMapUiState())
    val uiState: StateFlow<ParkMapUiState> = _uiState.asStateFlow()

    private val _navigationEvent = MutableSharedFlow<Int>()
    val navigationEvent: SharedFlow<Int> = _navigationEvent.asSharedFlow()

    private var beaconUuid: String? = null
    private var beaconMajorCode: Int? = null
    private var screenActive = false

    init {
        loadMarkers()
        observeBeacons()
    }

    private fun loadMarkers() {
        Log.w("ParkMapVM", "Loading Trail Markers")
        viewModelScope.launch {
            try {
                Log.w("ParkMapVM", "Executing call")
                trailRepository.loadData()
                val markers = trailRepository.getLandmarks().map { mark ->
                    MapMarker(
                        id = mark.id,
                        title = mark.name,
                        category = mark.category,
                        latitude = mark.coordinates.latitude,
                        longitude = mark.coordinates.longitude,
                    )
                }
                val coordinates = trailRepository.getFirstTrail()?.boundaryCoordinates?.map { item ->
                    Coordinates(item.latitude, item.longitude)
                } ?: emptyList()
                val boundary = trailRepository.getBoundary()
                _uiState.value = ParkMapUiState(markers = markers, coordinates = coordinates, boundary = boundary)

                beaconUuid = trailRepository.getBeaconUUID()
                beaconMajorCode = trailRepository.getBeaconMajorCode()
                if (screenActive) {
                    startScanningIfReady()
                }
            } catch (e: Exception) {
                Log.e("ParkMapVM", "Unable to load trails", e)
            }
        }
    }

    private fun observeBeacons() {
        viewModelScope.launch {
            beaconScanner.closestBeaconMinorCode
                .filterNotNull()
                .distinctUntilChanged()
                .collect { minorCode ->
                    _navigationEvent.emit(minorCode)
                }
        }
    }

    fun onScreenActive() {
        screenActive = true
        startScanningIfReady()
    }

    fun onScreenInactive() {
        screenActive = false
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
        const val SCAN_CONSUMER = "park_map"
    }

    fun getMarkerById(id: Int): MapMarker? = _uiState.value.markers.find { it.id == id }

    fun getLandmarkForMarker(markerId: Int): Landmark? = trailRepository.getLandmarkById(markerId)
}
