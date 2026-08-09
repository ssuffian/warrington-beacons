package org.warringtontownship.parks.android.beacon

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnnouncementGateTest {

    private var now = 0L
    private fun gate() = AnnouncementGate(clock = { now })

    /** Pass the distance gate [times] times; returns whether any call announced. */
    private fun sight(gate: AnnouncementGate, minor: Int, times: Int, distance: Double = 5.0): Boolean {
        var announced = false
        repeat(times) { if (gate.shouldAnnounce(minor, distance)) announced = true }
        return announced
    }

    @Test
    fun `announces only on the third sighting`() {
        val gate = gate()
        assertFalse(gate.shouldAnnounce(7, 5.0))
        assertFalse(gate.shouldAnnounce(7, 5.0))
        assertTrue(gate.shouldAnnounce(7, 5.0))
    }

    @Test
    fun `ignores beacons beyond thirty metres however many times they are seen`() {
        val gate = gate()
        assertFalse(sight(gate, 7, times = 10, distance = 30.0))
        assertFalse(sight(gate, 7, times = 10, distance = 80.0))
    }

    @Test
    fun `ignores negative distances, which altbeacon uses for unknown`() {
        val gate = gate()
        assertFalse(sight(gate, 7, times = 10, distance = -1.0))
    }

    @Test
    fun `refuses to announce the same landmark twice in a row`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        now += 120_000
        assertFalse(sight(gate, 7, times = 3))
    }

    @Test
    fun `announces a different landmark immediately after another`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        assertTrue(sight(gate, 8, times = 3))
    }

    @Test
    fun `re-announces a landmark after the cooldown once another has intervened`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        assertTrue(sight(gate, 8, times = 3))
        // 7 is no longer the last announced, but its own cooldown is still running.
        now += 59_000
        assertFalse(sight(gate, 7, times = 3))
        now += 2_000
        assertTrue(sight(gate, 7, times = 3))
    }

    @Test
    fun `sightings that fail the distance gate do not count toward confirmation`() {
        val gate = gate()
        gate.shouldAnnounce(7, 80.0)
        gate.shouldAnnounce(7, 80.0)
        assertFalse(gate.shouldAnnounce(7, 5.0))
    }

    @Test
    fun `lingering with BLE flicker does not re-announce within the cooldown`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))

        // A momentary empty ranging cycle: forgets we were just at 7, but must not
        // forget when 7 was last announced. If it cleared the cooldown map too,
        // this would wrongly announce again a few seconds later.
        gate.onNoBeaconsInRange()
        now += 5_000 // well under the 60s cooldown
        assertFalse(sight(gate, 7, times = 3))
    }

    @Test
    fun `lingering past the cooldown announces again after losing sight`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))

        gate.onNoBeaconsInRange()
        now += 60_000 // cooldown has now fully elapsed
        assertTrue(sight(gate, 7, times = 3))
    }
}
