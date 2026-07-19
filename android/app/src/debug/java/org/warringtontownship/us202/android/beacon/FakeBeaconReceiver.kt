package org.warringtontownship.us202.android.beacon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * Debug-build-only receiver that fakes beacon detections, so beacon-driven UI can be
 * exercised on the emulator (which has no usable Bluetooth radio).
 *
 * Fake a single beacon (minor = landmark id, distance in meters, default 1.0):
 *
 *   adb shell am broadcast \
 *     -n org.warringtontownship.us202.android/.beacon.FakeBeaconReceiver \
 *     -a org.warringtontownship.us202.FAKE_BEACON --ei minor 7 --ef distance 2.5
 *
 * Fake several beacons at once ("minor:distance" pairs):
 *
 *   adb shell am broadcast \
 *     -n org.warringtontownship.us202.android/.beacon.FakeBeaconReceiver \
 *     -a org.warringtontownship.us202.FAKE_BEACON --es beacons "7:2.5,8:10,4001:40"
 *
 * Clear all fake beacons (as if you walked out of range):
 *
 *   adb shell am broadcast \
 *     -n org.warringtontownship.us202.android/.beacon.FakeBeaconReceiver \
 *     -a org.warringtontownship.us202.FAKE_BEACON_CLEAR
 *
 * Note: leaving a beacon-consuming screen calls stopScanning(), which clears these
 * values just like real detections, so re-send after navigating.
 */
@AndroidEntryPoint
class FakeBeaconReceiver : BroadcastReceiver() {

    @Inject
    lateinit var beaconScanner: BeaconScanner

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FAKE_BEACON -> {
                val beacons = parseBeacons(intent)
                Log.i(TAG, "Faking beacons: $beacons")
                beaconScanner.injectSimulatedBeacons(beacons)
            }
            ACTION_FAKE_BEACON_CLEAR -> {
                Log.i(TAG, "Clearing fake beacons")
                beaconScanner.injectSimulatedBeacons(emptyList())
            }
            else -> Log.w(TAG, "Ignoring unknown action ${intent.action}")
        }
    }

    private fun parseBeacons(intent: Intent): List<DetectedBeacon> {
        intent.getStringExtra(EXTRA_BEACONS)?.let { spec ->
            return spec.split(",").mapNotNull { entry ->
                val parts = entry.trim().split(":")
                val minor = parts.getOrNull(0)?.toIntOrNull()
                if (minor == null) {
                    Log.w(TAG, "Skipping malformed beacon spec '$entry'")
                    return@mapNotNull null
                }
                val distance = parts.getOrNull(1)?.toDoubleOrNull() ?: DEFAULT_DISTANCE
                DetectedBeacon(minorCode = minor, distance = distance)
            }
        }
        val minor = intent.getIntExtra(EXTRA_MINOR, -1)
        if (minor < 0) {
            Log.w(TAG, "No 'beacons' or 'minor' extra provided; nothing to fake")
            return emptyList()
        }
        val distance = intent.getFloatExtra(EXTRA_DISTANCE, DEFAULT_DISTANCE.toFloat())
        return listOf(DetectedBeacon(minorCode = minor, distance = distance.toDouble()))
    }

    private companion object {
        const val TAG = "FakeBeaconReceiver"
        const val ACTION_FAKE_BEACON = "org.warringtontownship.us202.FAKE_BEACON"
        const val ACTION_FAKE_BEACON_CLEAR = "org.warringtontownship.us202.FAKE_BEACON_CLEAR"
        const val EXTRA_BEACONS = "beacons"
        const val EXTRA_MINOR = "minor"
        const val EXTRA_DISTANCE = "distance"
        const val DEFAULT_DISTANCE = 1.0
    }
}
