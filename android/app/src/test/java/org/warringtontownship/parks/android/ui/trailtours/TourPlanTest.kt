package org.warringtontownship.parks.android.ui.trailtours

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.warringtontownship.parks.android.data.TrailsDataParsingTest
import org.warringtontownship.parks.android.data.model.TrailCoordinate
import org.warringtontownship.parks.android.data.model.TrailsData
import java.io.File

class TourPlanTest {

    private val data: TrailsData =
        Gson().fromJson(File(TrailsDataParsingTest.DATA_FILE).readText(), TrailsData::class.java)

    private fun trail(id: String) = data.trails.first { it.id == id }

    private fun stops(vararg ids: String) = ids.map { TrailCoordinate(40.0, -75.0, landmarkId = it) }

    @Test
    fun `forward past the last stop leads to the trail end when present`() {
        assertEquals(TourNext.Stop(2), nextInTour(3, 1, reverse = false, hasStart = false, hasEnd = true))
        assertEquals(TourNext.TrailEnd, nextInTour(3, 2, reverse = false, hasStart = false, hasEnd = true))
        // Without an end the existing wrap-around preview is kept.
        assertEquals(TourNext.Stop(0), nextInTour(3, 2, reverse = false, hasStart = true, hasEnd = false))
    }

    @Test
    fun `reverse past the first stop leads to the trail start when present`() {
        assertEquals(TourNext.Stop(0), nextInTour(3, 1, reverse = true, hasStart = true, hasEnd = false))
        assertEquals(TourNext.TrailStart, nextInTour(3, 0, reverse = true, hasStart = true, hasEnd = false))
        assertEquals(TourNext.Stop(2), nextInTour(3, 0, reverse = true, hasStart = false, hasEnd = true))
    }

    @Test
    fun `a single-stop trail does not crash and uses its endpoints`() {
        assertEquals(TourNext.TrailEnd, nextInTour(1, 0, reverse = false, hasStart = true, hasEnd = true))
        assertEquals(TourNext.TrailStart, nextInTour(1, 0, reverse = true, hasStart = true, hasEnd = true))
        assertEquals(TourNext.Stop(0), nextInTour(1, 0, reverse = false, hasStart = false, hasEnd = false))
    }

    @Test
    fun `initial index prefers the chosen stop, else the direction's first stop`() {
        val s = stops("A", "B", "C")
        assertEquals(1, initialTourIndex(s, "B", reverse = false))
        assertEquals(1, initialTourIndex(s, "B", reverse = true))
        assertEquals(0, initialTourIndex(s, null, reverse = false))
        assertEquals(2, initialTourIndex(s, null, reverse = true))
        assertEquals(0, initialTourIndex(s, "missing", reverse = true))
        assertEquals(0, initialTourIndex(emptyList(), null, reverse = true))
    }

    @Test
    fun `trailhead is the start going forward and the end in reverse`() {
        val connector = trail("route-202-connector-trail")
        assertEquals(TRAIL_START_TITLE, trailheadFor(connector, reverse = false)?.title)
        assertNull(trailheadFor(connector, reverse = true))

        val lowerNike = trail("lower-nike-trail")
        assertNull(trailheadFor(lowerNike, reverse = false))
        assertEquals(TRAIL_END_TITLE, trailheadFor(lowerNike, reverse = true)?.title)

        assertNull(trailheadFor(trail("yellow-trail"), reverse = false))
    }

    @Test
    fun `endpoint markers are distinct and never collide with place ids`() {
        val connector = endpointMarkers(trail("route-202-connector-trail"))
        assertEquals(listOf(TRAIL_START_TITLE), connector.map { it.title })
        val lowerNike = endpointMarkers(trail("lower-nike-trail"))
        assertEquals(listOf(TRAIL_END_TITLE), lowerNike.map { it.title })
        assertTrue((connector + lowerNike).all { it.isEndpoint })
        val placeIds = data.landmarks.map { it.id }.toSet()
        assertTrue((connector + lowerNike).none { it.id in placeIds })
        assertTrue(endpointMarkers(trail("yellow-trail")).isEmpty())
    }

    @Test
    fun `a trail with no stops has no tour stops but still has its start`() {
        val connector = trail("route-202-connector-trail")
        assertTrue(tourStops(connector).isEmpty())
        assertEquals(1, endpointMarkers(connector).size)
    }
}
