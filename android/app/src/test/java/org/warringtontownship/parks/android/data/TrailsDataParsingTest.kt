package org.warringtontownship.parks.android.data

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.warringtontownship.parks.android.data.model.TrailsData
import java.io.File

class TrailsDataParsingTest {

    private val data: TrailsData =
        Gson().fromJson(File(DATA_FILE).readText(), TrailsData::class.java)

    @Test
    fun `parses both locations with their beacon major codes`() {
        assertEquals("035a0617-0875-4cc7-a29c-be0caa8f557c", data.beaconUUID)
        assertEquals(
            mapOf("lions-pride-park" to 17, "us-202" to 20),
            data.locations.associate { it.id to it.beaconMajorCode },
        )
        assertTrue(data.locations.all { it.address.isNotBlank() })
    }

    @Test
    fun `parses every landmark and trail from both locations`() {
        assertEquals(40, data.landmarks.size)
        assertEquals(4, data.trails.size)
        assertEquals(23, data.landmarks.count { it.location == "lions-pride-park" })
        assertEquals(17, data.landmarks.count { it.location == "us-202" })
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
    fun `nullable landmark fields survive absence`() {
        // Several landmarks have no isOpen / trailDistanceDescription in the source data.
        assertNotNull(data.landmarks.first { it.isOpen == null })
    }

    companion object {
        const val DATA_FILE = "../../server/warrington-trails.json"
    }
}
