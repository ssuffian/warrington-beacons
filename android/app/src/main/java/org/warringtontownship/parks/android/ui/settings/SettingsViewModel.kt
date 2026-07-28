package org.warringtontownship.parks.android.ui.settings

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.beacon.BeaconScanner
import org.warringtontownship.parks.android.data.prefs.AppPreferences
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject

data class BeaconDisplayItem(
    val landmarkName: String,
    val distance: Double,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val appPreferences: AppPreferences,
    private val beaconScanner: BeaconScanner,
    private val trailRepository: TrailRepository,
) : ViewModel() {

    val simplifiedText: StateFlow<Boolean> = appPreferences.simplifiedText

    private val _beaconList = MutableStateFlow<List<BeaconDisplayItem>>(emptyList())
    val beaconList: StateFlow<List<BeaconDisplayItem>> = _beaconList.asStateFlow()

    private var beaconRegions: List<BeaconRegion> = emptyList()
    private var screenActive = false

    init {
        loadBeaconConfig()
        observeBeacons()
    }

    private fun loadBeaconConfig() {
        viewModelScope.launch {
            try {
                trailRepository.loadData()
            } catch (e: Exception) {
                Log.e("SettingsVM", "Unable to load beacon config", e)
                return@launch
            }
            beaconRegions = trailRepository.getBeaconRegions()
            if (screenActive) {
                startScanningIfReady()
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
        const val SCAN_CONSUMER = "settings"
    }

    private fun observeBeacons() {
        viewModelScope.launch {
            beaconScanner.detectedBeacons.collect { beacons ->
                _beaconList.value = beacons.map { beacon ->
                    val landmark = trailRepository.getLandmarkById(beacon.minorCode)
                    BeaconDisplayItem(
                        landmarkName = landmark?.name ?: "Unknown (${beacon.minorCode})",
                        distance = beacon.distance,
                    )
                }
            }
        }
    }

    fun setSimplifiedText(enabled: Boolean) = appPreferences.setSimplifiedText(enabled)
}
