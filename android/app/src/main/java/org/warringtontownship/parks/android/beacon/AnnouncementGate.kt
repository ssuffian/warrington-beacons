package org.warringtontownship.parks.android.beacon

// Copied from the iOS app's BeaconScanner.swift, where they were derived from real
// trail behaviour. Do not retune without walking a trail.
internal const val MAX_ANNOUNCE_DISTANCE_METERS = 30.0
internal const val MIN_SEEN_COUNT = 3
internal const val COOLDOWN_MILLIS = 60_000L

/**
 * The rules that decide whether a ranged beacon is worth telling the user about:
 *
 *  - only beacons within [MAX_ANNOUNCE_DISTANCE_METERS] (a negative distance means
 *    altbeacon could not estimate one)
 *  - seen [MIN_SEEN_COUNT] times, so a single stray reading can't fire
 *  - never the landmark announced immediately before
 *  - at most once per [COOLDOWN_MILLIS] per landmark, which is also what lets a
 *    user who dismissed a landmark hear it again by lingering
 *
 * [clock] is injected so cooldown behaviour can be tested without sleeping.
 * Not thread-safe: callers serialise access (the announcer collects on a single
 * coroutine).
 */
internal class AnnouncementGate(private val clock: () -> Long) {

    private val seenCount = mutableMapOf<Int, Int>()
    private val lastAnnouncedAt = mutableMapOf<Int, Long>()
    private var lastAnnouncedMinor: Int? = null

    fun shouldAnnounce(minorCode: Int, distanceMeters: Double): Boolean {
        if (distanceMeters < 0.0 || distanceMeters >= MAX_ANNOUNCE_DISTANCE_METERS) return false

        val count = (seenCount[minorCode] ?: 0) + 1
        seenCount[minorCode] = count
        if (count < MIN_SEEN_COUNT) return false

        if (lastAnnouncedMinor == minorCode) return false

        val now = clock()
        val previous = lastAnnouncedAt[minorCode]
        if (previous != null && now - previous < COOLDOWN_MILLIS) return false

        lastAnnouncedAt[minorCode] = now
        lastAnnouncedMinor = minorCode
        // Matches iOS clearing beaconSeenCount after a notification, so the next
        // announcement needs a fresh run of sightings.
        seenCount.clear()
        return true
    }

    /**
     * Call when a ranging cycle sees no beacons at all — whether that's a momentary
     * BLE dropout or scanning stopping outright. Matches iOS's BeaconScanner, which
     * clears `lastNearbyBeaconId` but not `lastNotificationCache` on an empty cycle:
     * forgets which landmark you were just at (so leaving and coming back to the
     * same one within its cooldown doesn't get blocked forever by the "never twice
     * in a row" rule), but keeps every landmark's cooldown timer running (so a brief
     * dropout can't be used to hear the same landmark again before 60 seconds are up).
     */
    fun onNoBeaconsInRange() {
        seenCount.clear()
        lastAnnouncedMinor = null
    }
}
