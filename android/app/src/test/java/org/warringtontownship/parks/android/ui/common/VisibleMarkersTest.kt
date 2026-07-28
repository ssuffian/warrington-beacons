package org.warringtontownship.parks.android.ui.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VisibleMarkersTest {

    private fun marker(id: Int, category: String) =
        TrailMapMarker(id, "landmark $id", category, 40.24, -75.17)

    // Mirrors the real data: 4 trailheads (3 Lions Pride + 1 US202) among 40 landmarks.
    private val allMarkers = buildList {
        add(marker(1002, "Trail"))
        add(marker(3001, "Trail"))
        add(marker(3002, "Trail"))
        add(marker(4001, "Trail"))
        repeat(34) { add(marker(it + 1, "PointOfInterest")) }
        add(marker(90, "Building"))
        add(marker(91, "Building"))
    }

    @Test
    fun `zoomed out shows only trailheads when collapsing is enabled`() {
        val visible = visibleMarkersFor(
            markers = allMarkers,
            visibleSpanMeters = 5717.0, // the combined-bounds view of both locations
            collapseWhenZoomedOut = true,
        )
        assertEquals(4, visible.size)
        assertTrue(visible.all { it.category == "Trail" })
    }

    @Test
    fun `zoomed in shows every marker`() {
        val visible = visibleMarkersFor(
            markers = allMarkers,
            visibleSpanMeters = 300.0, // roughly the Lions Pride Park cluster
            collapseWhenZoomedOut = true,
        )
        assertEquals(allMarkers.size, visible.size)
    }

    @Test
    fun `the tour screens are unaffected, so their stops never disappear`() {
        // A tour's stops are mostly PointOfInterest; collapsing them would empty the map.
        val tourStops = allMarkers.filter { it.category != "Trail" }
        val visible = visibleMarkersFor(
            markers = tourStops,
            visibleSpanMeters = 5717.0,
            collapseWhenZoomedOut = false,
        )
        assertEquals(tourStops.size, visible.size)
    }

    @Test
    fun `an unknown span shows only trailheads rather than the full pile`() {
        // Before the first zoom/scroll event the span is unknown; erring toward the
        // collapsed view means the very first frame is readable rather than a blob.
        val visible = visibleMarkersFor(
            markers = allMarkers,
            visibleSpanMeters = Double.MAX_VALUE,
            collapseWhenZoomedOut = true,
        )
        assertEquals(4, visible.size)
    }

    @Test
    fun `the threshold sits between the two real view scales`() {
        // Guards the constant itself: the combined view must collapse and the
        // park-sized view must not, or the feature silently stops working.
        assertTrue(DETAIL_SPAN_METERS in 300.0..5717.0)
    }
}
