package org.warringtontownship.parks.android.data

import com.google.gson.Gson
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.data.model.TrailsData
import org.warringtontownship.parks.android.data.network.TrailsApiService
import org.warringtontownship.parks.android.data.network.TrailsApiContract
import org.warringtontownship.parks.android.data.repository.TrailRepository
import java.io.File
import okhttp3.ResponseBody.Companion.toResponseBody

class TrailRepositoryTest {

    private class FakeApiService : TrailsApiService {
        override suspend fun getTrailKml(): okhttp3.ResponseBody = throw java.io.IOException("Offline KML")
        override suspend fun getTrailsData(): TrailsData =
            Gson().fromJson(
                File(TrailsDataParsingTest.DATA_FILE).readText(),
                TrailsData::class.java,
            )
    }

    private lateinit var repository: TrailRepository

    @Before
    fun setUp() = runBlocking {
        repository = TrailRepository(FakeApiService())
        repository.loadData()
    }

    @Test
    fun `exposes every landmark and trail as one flat set`() {
        assertEquals(34, repository.getLandmarks().size)
        assertEquals(14, repository.getTrails().size)
        assertEquals("Yellow Trail", repository.getTrailById("yellow-trail")?.name)
        assertEquals("202 Connector Trail", repository.getTrailById("route-202-connector-trail")?.name)
    }

    @Test
    fun `pins network data to API version three`() {
        assertEquals("v3", TrailsApiContract.VERSION)
        assertEquals("api/v3/trails.json", TrailsApiContract.DATA_PATH)
        assertEquals("api/v3/talking-trails.kml", TrailsApiContract.KML_PATH)
    }

    @Test
    fun `KML replaces overview geometry without importing its point markers`() = runBlocking {
        val api = object : TrailsApiService {
            override suspend fun getTrailsData(): TrailsData = FakeApiService().getTrailsData()
            override suspend fun getTrailKml(): okhttp3.ResponseBody =
                File("../../server/api/v3/talking-trails.kml").readText().toResponseBody()
        }
        val repo = TrailRepository(api)
        repo.loadData()
        assertEquals(15, repo.getMapRoutes().size)
        assertEquals(34, repo.getLandmarks().size)
        assertEquals(14, repo.getTrails().size)
        assertEquals(34 + repo.getMapRoutes().sumOf { it.size }, repo.getCombinedBounds().size)
    }

    @Test
    fun `groups trails by location in locations order`() {
        val grouped = repository.getTrailsByLocation()
        assertEquals(listOf("lions-pride-park", "us-202", "upper-nike-park", "lower-nike-park",
            "weisel-preserve", "mill-creek-park", "ipw-park", "emerson-preserve"), grouped.map { it.first.id })
        assertEquals(listOf(4, 2, 1, 1, 1, 3, 1, 1), grouped.map { it.second.size })
        assertTrue(grouped[0].second.all { it.location == "lions-pride-park" })
    }

    @Test
    fun `builds image urls from the domain root`() {
        val landmark = repository.getLandmarkById("LP-2")!!
        assertEquals(
            "https://trails.warringtoneac.org/lions-pride-park/images/Yellow_trail.jpg",
            repository.imageUrlFor(landmark),
        )
    }

    @Test
    fun `combined bounds span both locations`() {
        val bounds = repository.getCombinedBounds()
        // KML-derived landmark coordinates plus generated tour route points.
        assertEquals(34 + repository.getTrails().sumOf { it.boundaryCoordinates.size }, bounds.size)
        val latitudes = bounds.map { it.latitude }
        val longitudes = bounds.map { it.longitude }
        assertTrue(latitudes.min() < 40.228 && latitudes.max() > 40.269)
        assertTrue(longitudes.min() < -75.191 && longitudes.max() > -75.159)
        // Both clusters are represented, not just the wider US202 corridor.
        assertTrue(bounds.any { it.latitude > 40.245 && it.latitude < 40.249 })
    }

    @Test
    fun `per-trail bounds cover only that trail`() {
        val bounds = repository.getBoundsForTrail("yellow-trail")
        assertEquals(repository.getTrailById("yellow-trail")!!.boundaryCoordinates.size, bounds.size)
        assertTrue(bounds.all { it.latitude > 40.246 && it.latitude < 40.248 })
        assertTrue(repository.getBoundsForTrail("missing-trail").isEmpty())
    }

    @Test
    fun `per-trail bounds include the trail start and end`() {
        val connector = repository.getTrailById("route-202-connector-trail")!!
        val bounds = repository.getBoundsForTrail(connector.id)
        assertEquals(connector.boundaryCoordinates.size + 1, bounds.size)
        assertEquals(connector.start!!.latitude, bounds.last().latitude, 0.0)
    }

    @Test
    fun `beacons match places by beaconMinor, never by place ID`() {
        assertEquals("LP-2", repository.getLandmarkByBeaconMinor(1002)?.id)
        assertNull(repository.getLandmarkByBeaconMinor(65535))
    }

    @Test
    fun `a place without beaconMinor is never matched by a beacon`() = runBlocking {
        val base = FakeApiService().getTrailsData()
        val beaconFree = base.landmarks.first().copy(id = "NB-1", beaconMinor = null)
        val api = object : TrailsApiService {
            override suspend fun getTrailKml(): okhttp3.ResponseBody = throw java.io.IOException("Offline KML")
            override suspend fun getTrailsData(): TrailsData =
                base.copy(landmarks = listOf(beaconFree) + base.landmarks.drop(1))
        }
        val repo = TrailRepository(api)
        repo.loadData()
        assertEquals("NB-1", repo.getLandmarkById("NB-1")?.id)
        // Its former minor, and every value no remaining place broadcasts, match nothing.
        val formerMinor = base.landmarks.first().beaconMinor!!
        assertNull(repo.getLandmarkByBeaconMinor(formerMinor))
        val minors = repo.getLandmarks().mapNotNull { it.beaconMinor }.toSet()
        assertTrue((0..65535).filterNot { it in minors }.all { repo.getLandmarkByBeaconMinor(it) == null })
        assertTrue(minors.all { repo.getLandmarkByBeaconMinor(it)?.id != "NB-1" })
    }

    @Test
    fun `groups landmarks by location in locations order`() {
        val grouped = repository.getLandmarksByLocation()
        assertEquals(listOf("lions-pride-park", "us-202", "upper-nike-park", "lower-nike-park",
            "weisel-preserve", "mill-creek-park", "ipw-park", "emerson-preserve"),
            grouped.map { it.first.id })
        assertEquals(listOf(20, 0, 2, 9, 3, 0, 0, 0), grouped.map { it.second.size })
        assertEquals(34, grouped.sumOf { it.second.size })
    }

    @Test
    fun `ranges every location major under both advertisement UUIDs`() {
        // Each beacon dual-advertises, and the frames can carry different UUIDs
        // (Lions Pride AltBeacon frames use 00112233-…), so every major must be
        // ranged under both of its location's UUIDs or one frame is invisible to
        // the scanner. US-202's two UUIDs match, so it collapses to one region.
        assertEquals(
            listOf(
                BeaconRegion("035a0617-0875-4cc7-a29c-be0caa8f557c", 17),
                BeaconRegion("00112233-4455-6677-8899-aabbccddeeff", 17),
                BeaconRegion("035a0617-0875-4cc7-a29c-be0caa8f557c", 20),
            ),
            repository.getBeaconRegions(),
        )
    }
}
