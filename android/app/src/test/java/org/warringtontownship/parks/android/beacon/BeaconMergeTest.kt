package org.warringtontownship.parks.android.beacon

import org.junit.Assert.assertEquals
import org.junit.Test

class BeaconMergeTest {

    private fun beacon(minor: Int, distance: Double) = DetectedBeacon(minor, distance)

    @Test
    fun `an empty cycle for one region does not clear the other region`() {
        val merged = mergeDetections(
            mapOf(
                "region-17" to emptyList(),
                "region-20" to listOf(beacon(4, 2.0)),
            )
        )
        assertEquals(listOf(beacon(4, 2.0)), merged)
    }

    @Test
    fun `closest is the minimum across all regions, nearest first`() {
        val merged = mergeDetections(
            mapOf(
                "region-17" to listOf(beacon(1002, 1.5), beacon(3001, 12.0)),
                "region-20" to listOf(beacon(4, 3.0)),
            )
        )
        assertEquals(listOf(1002, 4, 3001), merged.map { it.minorCode })
    }

    @Test
    fun `no detections anywhere yields an empty list`() {
        assertEquals(
            emptyList<DetectedBeacon>(),
            mergeDetections(mapOf("region-17" to emptyList(), "region-20" to emptyList())),
        )
    }
}
