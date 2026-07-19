package org.warringtontownship.us202.android.beacon

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

@Singleton
class BeaconScanner @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val beaconManager: BeaconManager = BeaconManager.getInstanceForApplication(context)
    private var region: Region? = null
    // Keyed by consumer so an unbalanced stop (e.g. a screen that never managed to
    // start, or onCleared firing after onScreenInactive) can't stop another screen's scan.
    private val activeConsumers = mutableSetOf<String>()

    private val _closestBeaconMinorCode = MutableStateFlow<Int?>(null)
    val closestBeaconMinorCode: StateFlow<Int?> = _closestBeaconMinorCode.asStateFlow()

    private val _detectedBeacons = MutableStateFlow<List<DetectedBeacon>>(emptyList())
    val detectedBeacons: StateFlow<List<DetectedBeacon>> = _detectedBeacons.asStateFlow()

    @Volatile
    private var simulationActive = false

    private val rangeNotifier = RangeNotifier { beacons, _ ->
        if (simulationActive) return@RangeNotifier
        val closest = beacons.minByOrNull { it.distance }
        val minorCode = closest?.id3?.toInt()
        Log.d("BeaconScanner", "Ranged ${beacons.size} beacons, closest minor: $minorCode")
        _closestBeaconMinorCode.value = minorCode
        _detectedBeacons.value = beacons
            .mapNotNull { beacon ->
                val minor = beacon.id3?.toInt() ?: return@mapNotNull null
                DetectedBeacon(minorCode = minor, distance = beacon.distance)
            }
            .sortedBy { it.distance }
    }

    init {
        beaconManager.beaconParsers.add(
            BeaconParser().setBeaconLayout(BeaconParser.ALTBEACON_LAYOUT)
        )
    }

    fun startScanning(consumer: String, uuid: String, majorCode: Int) {
        if (!activeConsumers.add(consumer)) return
        Log.d("BeaconScanner", "Consumer $consumer added, active=$activeConsumers")
        if (activeConsumers.size == 1) {
            val region = Region(
                "park-beacons",
                Identifier.parse(uuid),
                Identifier.fromInt(majorCode),
                null,
            )
            this.region = region
            BeaconManager.setRssiFilterImplClass(ArmaRssiFilter::class.java)
            beaconManager.addRangeNotifier(rangeNotifier)
            beaconManager.startRangingBeacons(region)
            Log.d("BeaconScanner", "Started scanning for uuid=$uuid major=$majorCode")
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
            region?.let { beaconManager.stopRangingBeacons(it) }
            beaconManager.removeRangeNotifier(rangeNotifier)
            _closestBeaconMinorCode.value = null
            _detectedBeacons.value = emptyList()
            region = null
            Log.d("BeaconScanner", "Stopped scanning")
        }
    }
}
