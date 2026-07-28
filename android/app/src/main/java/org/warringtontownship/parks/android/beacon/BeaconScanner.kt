package org.warringtontownship.parks.android.beacon

import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.altbeacon.beacon.BeaconManager
import org.altbeacon.beacon.BeaconParser
import org.altbeacon.beacon.Identifier
import org.altbeacon.beacon.RangeNotifier
import org.altbeacon.beacon.Region
import org.altbeacon.beacon.service.ArmaRssiFilter
import javax.inject.Inject
import javax.inject.Singleton

data class DetectedBeacon(
    val minorCode: Int,
    val distance: Double,
)

/**
 * Altbeacon delivers range results per region, so state has to be accumulated per
 * region and merged. Overwriting state from a single callback would let an empty
 * cycle for one location clear a live detection from the other.
 */
internal fun mergeDetections(byRegion: Map<String, List<DetectedBeacon>>): List<DetectedBeacon> =
    byRegion.values.flatten().sortedBy { it.distance }

@Singleton
class BeaconScanner @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val beaconManager: BeaconManager = BeaconManager.getInstanceForApplication(context)
    private var regions: List<Region> = emptyList()
    private val detectionsByRegion = mutableMapOf<String, List<DetectedBeacon>>()
    // Keyed by consumer so an unbalanced stop (e.g. a screen that never managed to
    // start, or onCleared firing after onScreenInactive) can't stop another screen's scan.
    private val activeConsumers = mutableSetOf<String>()

    private val _closestBeaconMinorCode = MutableStateFlow<Int?>(null)
    val closestBeaconMinorCode: StateFlow<Int?> = _closestBeaconMinorCode.asStateFlow()

    private val _detectedBeacons = MutableStateFlow<List<DetectedBeacon>>(emptyList())
    val detectedBeacons: StateFlow<List<DetectedBeacon>> = _detectedBeacons.asStateFlow()

    @Volatile
    private var simulationActive = false

    private val rangeNotifier = RangeNotifier { beacons, region ->
        if (simulationActive) return@RangeNotifier
        val detected = beacons.mapNotNull { beacon ->
            val minor = beacon.id3?.toInt() ?: return@mapNotNull null
            DetectedBeacon(minorCode = minor, distance = beacon.distance)
        }
        val merged = synchronized(detectionsByRegion) {
            detectionsByRegion[region.uniqueId] = detected
            mergeDetections(detectionsByRegion)
        }
        Log.d("BeaconScanner", "Region ${region.uniqueId}: ${beacons.size} ranged, " +
            "merged closest ${merged.firstOrNull()?.minorCode}")
        _detectedBeacons.value = merged
        _closestBeaconMinorCode.value = merged.firstOrNull()?.minorCode
    }

    init {
        beaconManager.beaconParsers.add(
            BeaconParser().setBeaconLayout(BeaconParser.ALTBEACON_LAYOUT)
        )
    }

    fun startScanning(consumer: String, regions: List<BeaconRegion>) {
        if (regions.isEmpty()) return
        if (!activeConsumers.add(consumer)) return
        Log.d("BeaconScanner", "Consumer $consumer added, active=$activeConsumers")
        if (activeConsumers.size == 1) {
            val started = regions.map { spec ->
                Region(
                    "park-beacons-${spec.majorCode}",
                    Identifier.parse(spec.uuid),
                    Identifier.fromInt(spec.majorCode),
                    null,
                )
            }
            this.regions = started
            BeaconManager.setRssiFilterImplClass(ArmaRssiFilter::class.java)
            beaconManager.addRangeNotifier(rangeNotifier)
            started.forEach { beaconManager.startRangingBeacons(it) }
            Log.d("BeaconScanner", "Started scanning ${started.map { it.uniqueId }}")
        }
    }

    // Dev hook used by FakeBeaconReceiver (debug builds only) to drive the beacon
    // flows without radio hardware, e.g. on the emulator. While a non-empty simulation
    // is active, real scan cycles are ignored — otherwise each (empty) cycle would
    // overwrite the fake values within a second. Clearing (empty list) re-enables the
    // radio. stopScanning() still clears these values, same as real detections.
    fun injectSimulatedBeacons(beacons: List<DetectedBeacon>) {
        Log.d("BeaconScanner", "Injecting ${beacons.size} simulated beacons")
        simulationActive = beacons.isNotEmpty()
        _detectedBeacons.value = beacons.sortedBy { it.distance }
        _closestBeaconMinorCode.value = beacons.minByOrNull { it.distance }?.minorCode
    }

    fun stopScanning(consumer: String) {
        if (!activeConsumers.remove(consumer)) return
        Log.d("BeaconScanner", "Consumer $consumer removed, active=$activeConsumers")
        if (activeConsumers.isEmpty()) {
            regions.forEach { beaconManager.stopRangingBeacons(it) }
            beaconManager.removeRangeNotifier(rangeNotifier)
            synchronized(detectionsByRegion) { detectionsByRegion.clear() }
            _closestBeaconMinorCode.value = null
            _detectedBeacons.value = emptyList()
            regions = emptyList()
            Log.d("BeaconScanner", "Stopped scanning")
        }
    }
}
