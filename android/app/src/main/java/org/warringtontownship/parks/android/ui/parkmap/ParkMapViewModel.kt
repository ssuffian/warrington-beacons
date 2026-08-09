package org.warringtontownship.parks.android.ui.parkmap

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import org.warringtontownship.parks.android.beacon.AnnouncementText
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.beacon.BeaconScanner
import org.warringtontownship.parks.android.beacon.LandmarkAnnouncer
import org.warringtontownship.parks.android.data.repository.TrailRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import android.util.Log
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.data.model.Landmark

data class MapMarker(
    val id: Int,
    val title: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
)

data class ParkMapUiState(
    val markers: List<MapMarker> = emptyList(),
    val routes: List<List<Coordinates>> = emptyList(),
    val boundary: List<Coordinates> = emptyList(),
    val selectedMarker: MapMarker? = null,
)

@HiltViewModel
class ParkMapViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
    private val beaconScanner: BeaconScanner,
    private val announcer: LandmarkAnnouncer,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ParkMapUiState())
    val uiState: StateFlow<ParkMapUiState> = _uiState.asStateFlow()

    private val _navigationEvent = MutableSharedFlow<Int>()
    val navigationEvent: SharedFlow<Int> = _navigationEvent.asSharedFlow()

    private var beaconRegions: List<BeaconRegion> = emptyList()
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
                val routes = trailRepository.getTrails().map { trail ->
                    trail.boundaryCoordinates.map { Coordinates(it.latitude, it.longitude) }
                }
                val boundary = trailRepository.getCombinedBounds()
                _uiState.value = ParkMapUiState(markers = markers, routes = routes, boundary = boundary)

                beaconRegions = trailRepository.getBeaconRegions()
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
            announcer.currentLandmark.collect { landmark ->
                _navigationEvent.emit(landmark.id)
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
        if (beaconRegions.isEmpty()) return
        beaconScanner.startScanning(SCAN_CONSUMER, beaconRegions)
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

    fun imageUrlFor(landmark: Landmark): String = trailRepository.imageUrlFor(landmark)

    fun announcementTextFor(landmarkId: Int): AnnouncementText? {
        if (!announcer.isAnnouncingEnabled()) return null
        return trailRepository.getLandmarkById(landmarkId)?.let { announcer.textFor(it) }
    }
}
