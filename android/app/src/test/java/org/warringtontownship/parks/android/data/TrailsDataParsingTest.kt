package org.warringtontownship.parks.android.data

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.warringtontownship.parks.android.data.model.TrailsData
import java.io.File

class TrailsDataParsingTest {

    private val data: TrailsData =
        Gson().fromJson(File(DATA_FILE).readText(), TrailsData::class.java)

    @Test
    fun `parses both locations with their beacon major codes`() {
        // The beacons dual-advertise iBeacon and AltBeacon frames, each with its
        // own per-location UUID (they differ on Lions Pride hardware).
        assertEquals(
            mapOf(
                "lions-pride-park" to ("035a0617-0875-4cc7-a29c-be0caa8f557c" to "00112233-4455-6677-8899-aabbccddeeff"),
                "us-202" to ("035a0617-0875-4cc7-a29c-be0caa8f557c" to "035a0617-0875-4cc7-a29c-be0caa8f557c"),
            ),
            data.locations.associate { it.id to (it.iBeaconUUID to it.altBeaconUUID) },
        )
        assertEquals(
            mapOf("lions-pride-park" to 17, "us-202" to 20),
            data.locations.associate { it.id to it.beaconMajorCode },
        )
        assertTrue(data.locations.all { it.address.isNotBlank() })
    }

    @Test
    fun `parses every landmark and trail from both locations`() {
        assertEquals(34, data.landmarks.size)
        assertEquals(11, data.trails.size)
        assertEquals(20, data.landmarks.count { it.location == "lions-pride-park" })
        assertEquals(14, data.landmarks.count { it.location == "us-202" })
    }

    @Test
    fun `landmark ids are globally unique`() {
        val duplicates = data.landmarks.groupBy { it.id }.filterValues { it.size > 1 }.keys
        assertTrue("duplicate landmark ids: $duplicates", duplicates.isEmpty())
    }

    @Test
    fun `every location key resolves and every image path is present`() {
        val locationIds = data.locations.map { it.id }.toSet()
        data.landmarks.forEach { landmark ->
            assertTrue("bad location on ${landmark.id}", landmark.location in locationIds)
            assertTrue(
                "bad imagePath on ${landmark.id}: ${landmark.imagePath}",
                landmark.imagePath.endsWith(".jpg") && landmark.imagePath.contains("/images/"),
            )
            assertTrue(
                "missing image file for ${landmark.id}",
                File("../../server/${landmark.imagePath}").exists(),
            )
        }
        data.trails.forEach { assertTrue(it.location in locationIds) }
    }

    @Test
    fun `every trail stop references a known landmark`() {
        val ids = data.landmarks.map { it.id }.toSet()
        data.trails.forEach { trail ->
            trail.boundaryCoordinates.mapNotNull { it.landmarkId }.forEach { landmarkId ->
                assertTrue("trail ${trail.id} references $landmarkId", landmarkId in ids)
            }
        }
    }

    @Test
    fun `landmark ids are string recordKeys and beacon minors are optional and unique`() {
        val yellow = data.landmarks.first { it.id == "LP-2" }
        assertEquals("Yellow Trail", yellow.name)
        assertEquals(1002, yellow.beaconMinor)
        assertTrue(data.landmarks.all { it.id.matches(Regex("^[A-Za-z0-9][A-Za-z0-9._-]*$")) })
        val minors = data.landmarks.mapNotNull { it.beaconMinor }
        assertEquals(minors.size, minors.toSet().size)
        assertTrue(minors.all { it in 0..65535 })
    }

    @Test
    fun `a place without beaconMinor decodes with a null minor`() {
        val json = """{"locations":[],"trails":[],"landmarks":[{"id":"EAC-99","location":"us-202",
            "imagePath":"x.jpg","coordinates":{"latitude":40.2,"longitude":-75.1},"name":"No beacon",
            "category":"PointOfInterest","description":"d","longDescription":"l","imageAlt":"a"}]}"""
        val parsed = Gson().fromJson(json, TrailsData::class.java)
        assertEquals("EAC-99", parsed.landmarks.single().id)
        assertNull(parsed.landmarks.single().beaconMinor)
    }

    @Test
    fun `trail start and end are optional beacon-free endpoints`() {
        val connector = data.trails.first { it.id == "route-202-connector-trail" }
        assertNotNull(connector.start)
        assertNull(connector.end)
        assertTrue(connector.boundaryCoordinates.none { it.landmarkId != null })
        assertTrue(connector.start!!.directions.isNotBlank())
        assertEquals(40.2700344, connector.start!!.latitude, 1e-7)

        val lowerNike = data.trails.first { it.id == "lower-nike-trail" }
        assertNull(lowerNike.start)
        assertNotNull(lowerNike.end)
        assertEquals(-75.1586589, lowerNike.end!!.longitude, 1e-7)
        assertEquals("858 yards to Waterfowl", lowerNike.end!!.directions)
        assertTrue(lowerNike.boundaryCoordinates.count { it.landmarkId != null } > 1)

        val yellow = data.trails.first { it.id == "yellow-trail" }
        assertNull(yellow.start)
        assertNull(yellow.end)
        assertEquals("LP-4", yellow.boundaryCoordinates.first { it.landmarkId != null }.landmarkId)
    }

    @Test
    fun `nullable landmark fields survive absence`() {
        // Several landmarks have no isOpen / trailDistanceDescription in the source data.
        assertNotNull(data.landmarks.first { it.isOpen == null })
    }

    companion object {
        const val DATA_FILE = "../../server/api/v3/trails.json"
    }
}
