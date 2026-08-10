package org.warringtontownship.parks.android.ui.parkmap

import android.bluetooth.BluetoothManager
import android.content.Context
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.qualifiers.ApplicationContext
import org.warringtontownship.parks.android.beacon.AnnouncementText
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.beacon.BeaconScanner
import org.warringtontownship.parks.android.beacon.LandmarkAnnouncer
import org.warringtontownship.parks.android.data.prefs.AppPreferences
import org.warringtontownship.parks.android.data.repository.TrailRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
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

/**
 * What the status control says, as a pure function so the precedence is testable.
 *
 * Order matters: the states are reported most-decisive first. "Off" is the user's
 * own choice and outranks everything. Bluetooth off means no detection can happen
 * at all, so it outranks a notification problem. Blocked notifications still leave
 * on-screen announcements working, so it outranks the merely-degraded service. The
 * healthy message is last.
 */
internal fun statusFor(
    enabled: Boolean,
    bluetoothOn: Boolean,
    notificationsEnabled: Boolean,
    serviceFailed: Boolean,
): String = when {
    !enabled -> "Announcements off."
    !bluetoothOn -> "Bluetooth is off — announcements paused"
    !notificationsEnabled -> "Notifications are blocked — landmarks will only be announced on screen"
    serviceFailed -> "Announcements on, but only while this screen is open."
    else -> "Announcements on. Listening for nearby landmarks."
}

@HiltViewModel
class ParkMapViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val trailRepository: TrailRepository,
    private val beaconScanner: BeaconScanner,
    private val announcer: LandmarkAnnouncer,
    private val appPreferences: AppPreferences,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ParkMapUiState())
    val uiState: StateFlow<ParkMapUiState> = _uiState.asStateFlow()

    private val _navigationEvent = MutableSharedFlow<Int>()
    val navigationEvent: SharedFlow<Int> = _navigationEvent.asSharedFlow()

    val announcementsEnabled: StateFlow<Boolean> = appPreferences.announcementsEnabled

    // Bluetooth and notification state are polled rather than observed: both can be
    // changed from outside the app while it is backgrounded, and neither has a flow
    // worth registering a receiver for. Refreshed whenever the screen becomes active,
    // which is exactly when the user can read the result.
    private val _bluetoothOn = MutableStateFlow(readBluetoothOn())
    private val _notificationsEnabled = MutableStateFlow(readNotificationsEnabled())

    private fun readBluetoothOn(): Boolean = try {
        context.getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled == true
    } catch (e: SecurityException) {
        // Can't tell; don't claim the radio is off and send the user chasing a
        // setting that is already correct.
        Log.w("ParkMapVM", "Unable to read Bluetooth state", e)
        true
    }

    private fun readNotificationsEnabled(): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    private fun refreshSystemState() {
        _bluetoothOn.value = readBluetoothOn()
        _notificationsEnabled.value = readNotificationsEnabled()
    }

    val statusMessage: StateFlow<String> = combine(
        appPreferences.announcementsEnabled,
        _bluetoothOn,
        _notificationsEnabled,
        beaconScanner.foregroundServiceFailed,
    ) { enabled, bluetoothOn, notificationsEnabled, serviceFailed ->
        statusFor(enabled, bluetoothOn, notificationsEnabled, serviceFailed)
    }
        .stateIn(
            viewModelScope,
            SharingStarted.Eagerly,
            statusFor(
                appPreferences.announcementsEnabled.value,
                _bluetoothOn.value,
                _notificationsEnabled.value,
                beaconScanner.foregroundServiceFailed.value,
            ),
        )

    private var beaconRegions: List<BeaconRegion> = emptyList()
    private var screenActive = false
    private var scanStarted = false

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
        refreshSystemState()
        startScanningIfReady()
    }

    fun onScreenInactive() {
        screenActive = false
        stopScanning()
    }

    private fun startScanningIfReady() {
        if (!appPreferences.announcementsEnabled.value) return
        if (beaconRegions.isEmpty()) return
        beaconScanner.startScanning(SCAN_CONSUMER, beaconRegions)
        scanStarted = true
    }

    private fun stopScanning() {
        beaconScanner.stopScanning(SCAN_CONSUMER)
        scanStarted = false
    }

    /**
     * Called once the permission dialog resolves. On first launch this screen
     * registers its scanning consumer before the grant lands, and because the
     * consumer is already in the scanner's active set a plain start() is a no-op —
     * the foreground service would never get a second chance. Dropping the consumer
     * and re-adding it goes through the scanner's own reference counting, so the
     * service is genuinely torn down and rebuilt rather than worked around.
     */
    fun onPermissionResult() {
        refreshSystemState()
        if (!screenActive || !scanStarted) return
        stopScanning()
        startScanningIfReady()
    }

    fun setAnnouncementsEnabled(enabled: Boolean) {
        appPreferences.setAnnouncementsEnabled(enabled)
        if (enabled) startScanningIfReady() else stopScanning()
    }

    override fun onCleared() {
        super.onCleared()
        stopScanning()
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
