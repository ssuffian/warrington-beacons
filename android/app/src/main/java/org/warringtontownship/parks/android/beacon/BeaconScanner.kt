package org.warringtontownship.parks.android.beacon

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
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

/**
 * Stores the freshly ranged [detected] list for [regionId] into the accumulating
 * [byRegion] map, then returns the merge across all regions. This is the actual
 * hazard the multi-region change guards against: [byRegion] persists across calls,
 * so an empty cycle for one region only overwrites that region's entry — a live
 * detection recorded for another region on an earlier call survives.
 */
internal fun accumulateAndMerge(
    byRegion: MutableMap<String, List<DetectedBeacon>>,
    regionId: String,
    detected: List<DetectedBeacon>,
): List<DetectedBeacon> {
    byRegion[regionId] = detected
    return mergeDetections(byRegion)
}

/**
 * Advertisement layouts the scanner parses. The beacons dual-advertise iBeacon
 * and AltBeacon frames, and the two frames don't always carry the same UUID
 * (Lions Pride hardware uses 00112233-… on its AltBeacon frame), so both layouts
 * are registered and both UUIDs are ranged — registering only one layout, or
 * ranging only one UUID, silently blinds the scanner to one of the frames.
 */
internal const val IBEACON_LAYOUT = "m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24"

internal fun scannedBeaconLayouts(): List<String> =
    listOf(BeaconParser.ALTBEACON_LAYOUT, IBEACON_LAYOUT)

@Singleton
class BeaconScanner @Inject constructor(
    @ApplicationContext private val context: Context,
    private val notifier: AnnouncementNotifier,
) {
    private val beaconManager: BeaconManager = BeaconManager.getInstanceForApplication(context)
    private var regions: List<Region> = emptyList()
    private val detectionsByRegion = mutableMapOf<String, List<DetectedBeacon>>()
    // Guarded by the same lock as detectionsByRegion. Lets the notifier tell whether
    // stopScanning() has already run so it never publishes a stale value after the
    // flows have been cleared and the notifier detached.
    private var scanning = false
    // Keyed by consumer so an unbalanced stop (e.g. a screen that never managed to
    // start, or onCleared firing after onScreenInactive) can't stop another screen's scan.
    private val activeConsumers = mutableSetOf<String>()

    private val _closestBeaconMinorCode = MutableStateFlow<Int?>(null)
    val closestBeaconMinorCode: StateFlow<Int?> = _closestBeaconMinorCode.asStateFlow()

    private val _detectedBeacons = MutableStateFlow<List<DetectedBeacon>>(emptyList())
    val detectedBeacons: StateFlow<List<DetectedBeacon>> = _detectedBeacons.asStateFlow()

    private val _foregroundServiceFailed = MutableStateFlow(false)
    val foregroundServiceFailed: StateFlow<Boolean> = _foregroundServiceFailed.asStateFlow()

    @Volatile
    private var simulationActive = false

    private val rangeNotifier = RangeNotifier { beacons, region ->
        if (simulationActive) return@RangeNotifier
        val detected = beacons.mapNotNull { beacon ->
            val minor = beacon.id3?.toInt() ?: return@mapNotNull null
            DetectedBeacon(minorCode = minor, distance = beacon.distance)
        }
        synchronized(detectionsByRegion) {
            // If stopScanning() already ran, it cleared the flows under this same
            // lock; publishing here would resurrect a stale value with no further
            // callback ever arriving to correct it (the notifier is detached).
            if (!scanning) return@RangeNotifier
            val merged = accumulateAndMerge(detectionsByRegion, region.uniqueId, detected)
            Log.d("BeaconScanner", "Region ${region.uniqueId}: ${beacons.size} ranged, " +
                "merged closest ${merged.firstOrNull()?.minorCode}")
            _detectedBeacons.value = merged
            _closestBeaconMinorCode.value = merged.firstOrNull()?.minorCode
        }
    }

    init {
        scannedBeaconLayouts().forEach { layout ->
            beaconManager.beaconParsers.add(BeaconParser().setBeaconLayout(layout))
        }
    }

    /**
     * Either location permission satisfies the API 34+ foregroundServiceType="location"
     * rule, so coarse-only (the map's blue dot downgraded) still gets the service.
     */
    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    fun startScanning(consumer: String, regions: List<BeaconRegion>) {
        if (regions.isEmpty()) return
        if (!activeConsumers.add(consumer)) return
        Log.d("BeaconScanner", "Consumer $consumer added, active=$activeConsumers")
        if (activeConsumers.size == 1) {
            val started = regions.map { spec ->
                // uniqueId doubles as the accumulation key in detectionsByRegion,
                // so it must distinguish regions that share a major but range a
                // different advertisement UUID (iBeacon vs AltBeacon frame).
                Region(
                    "park-beacons-${spec.uuid}-${spec.majorCode}",
                    Identifier.parse(spec.uuid),
                    Identifier.fromInt(spec.majorCode),
                    null,
                )
            }
            this.regions = started
            synchronized(detectionsByRegion) {
                scanning = true
                detectionsByRegion.clear()
            }
            BeaconManager.setRssiFilterImplClass(ArmaRssiFilter::class.java)
            if (!hasLocationPermission()) {
                // Altbeacon's BeaconService declares foregroundServiceType="location",
                // and from API 34 starting such a service without a granted
                // fine/coarse location permission throws SecurityException. Altbeacon
                // catches that internally and never sets the flag
                // foregroundServiceStartFailed() reads, so asking it would report
                // success while scanning silently dies at screen-off. Decide here
                // instead: skip the service, report the degraded state honestly, and
                // still range while the app is in front.
                Log.w(
                    "BeaconScanner",
                    "Location permission not granted; skipping foreground service scanning",
                )
                _foregroundServiceFailed.value = true
            } else {
                try {
                    // Scheduled scan jobs and foreground-service scanning are mutually
                    // exclusive in altbeacon; the service is what keeps ranging alive with
                    // the screen off and the phone in a pocket. This can throw if a
                    // consumer is still bound from an unclean previous stop, so it stays
                    // inside the try — the catch below still lets ranging start in the
                    // (unprotected) foreground-only path rather than leaving the scanner
                    // believing it's live while nothing was ever wired up.
                    beaconManager.setEnableScheduledScanJobs(false)
                    beaconManager.enableForegroundServiceScanning(
                        notifier.scanningNotification(),
                        AnnouncementNotifier.SCANNING_NOTIFICATION_ID,
                    )
                    _foregroundServiceFailed.value = beaconManager.foregroundServiceStartFailed()
                } catch (e: IllegalStateException) {
                    // Already enabled, or not permitted. Ranging still works while the
                    // app is in front, so degrade rather than fail.
                    Log.w("BeaconScanner", "Foreground service scanning unavailable", e)
                    _foregroundServiceFailed.value = true
                }
            }
            beaconManager.addRangeNotifier(rangeNotifier)
            started.forEach { beaconManager.startRangingBeacons(it) }
            // foregroundServiceStartFailed() only reflects reality once the service
            // has actually attempted to bind, which happens inside
            // startRangingBeacons() above — re-read and OR in, so a true recorded by
            // the catch above is never clobbered by a stale pre-bind false here.
            _foregroundServiceFailed.value =
                _foregroundServiceFailed.value || beaconManager.foregroundServiceStartFailed()
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
            try {
                beaconManager.disableForegroundServiceScanning()
                _foregroundServiceFailed.value = false
            } catch (e: IllegalStateException) {
                // Still running despite the attempt to stop it; leave the flag as-is
                // rather than reporting a live service as fine.
                Log.w("BeaconScanner", "Foreground service already disabled", e)
            }
            synchronized(detectionsByRegion) {
                scanning = false
                detectionsByRegion.clear()
                _closestBeaconMinorCode.value = null
                _detectedBeacons.value = emptyList()
            }
            regions = emptyList()
            Log.d("BeaconScanner", "Stopped scanning")
        }
    }
}
