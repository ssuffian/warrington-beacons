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

    @Test
    fun `accumulation across successive callbacks keeps a live detection when another region goes empty`() {
        val byRegion = mutableMapOf<String, List<DetectedBeacon>>()

        val afterRegion20Reports = accumulateAndMerge(byRegion, "region-20", listOf(beacon(4, 2.0)))
        assertEquals(listOf(beacon(4, 2.0)), afterRegion20Reports)

        val afterRegion17Empty = accumulateAndMerge(byRegion, "region-17", emptyList())
        assertEquals(listOf(beacon(4, 2.0)), afterRegion17Empty)

        val afterRegion20Empty = accumulateAndMerge(byRegion, "region-20", emptyList())
        assertEquals(emptyList<DetectedBeacon>(), afterRegion20Empty)
    }
}
