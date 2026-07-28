package org.warringtontownship.parks.android.ui.settings

import android.app.Application
import android.content.Context
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
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject

data class BeaconDisplayItem(
    val landmarkName: String,
    val distance: Double,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    application: Application,
    private val beaconScanner: BeaconScanner,
    private val trailRepository: TrailRepository,
) : ViewModel() {

    private val prefs = application.getSharedPreferences("warrington_prefs", Context.MODE_PRIVATE)

    private val _simplifiedText = MutableStateFlow(prefs.getBoolean("simplified_text", false))
    val simplifiedText: StateFlow<Boolean> = _simplifiedText.asStateFlow()

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
        val region = beaconRegions.firstOrNull() ?: return
        beaconScanner.startScanning(SCAN_CONSUMER, region.uuid, region.majorCode)
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

    fun setSimplifiedText(enabled: Boolean) {
        prefs.edit().putBoolean("simplified_text", enabled).apply()
        _simplifiedText.value = enabled
    }
}
