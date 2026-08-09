package org.warringtontownship.parks.android.data

import com.google.gson.Gson
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.data.model.TrailsData
import org.warringtontownship.parks.android.data.network.TrailsApiService
import org.warringtontownship.parks.android.data.repository.TrailRepository
import java.io.File

class TrailRepositoryTest {

    private class FakeApiService : TrailsApiService {
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
        assertEquals(40, repository.getLandmarks().size)
        assertEquals(4, repository.getTrails().size)
        assertEquals("Yellow Trail", repository.getTrailById(1002)?.name)
        assertEquals("202 Connector Trail", repository.getTrailById(4001)?.name)
    }

    @Test
    fun `groups trails by location in locations order`() {
        val grouped = repository.getTrailsByLocation()
        assertEquals(listOf("Lions Pride Park", "US202 to Bradford Dam"), grouped.map { it.first.name })
        assertEquals(3, grouped[0].second.size)
        assertEquals(1, grouped[1].second.size)
        assertTrue(grouped[0].second.all { it.location == "lions-pride-park" })
    }

    @Test
    fun `builds image urls from the domain root`() {
        val landmark = repository.getLandmarkById(1002)!!
        assertEquals(
            "https://trails.warringtoneac.org/lions-pride-park/images/Yellow_trail.jpg",
            repository.imageUrlFor(landmark),
        )
    }

    @Test
    fun `combined bounds span both locations`() {
        val bounds = repository.getCombinedBounds()
        // 40 landmark coordinates plus 887 trail polyline points.
        assertEquals(927, bounds.size)
        val latitudes = bounds.map { it.latitude }
        val longitudes = bounds.map { it.longitude }
        assertTrue(latitudes.min() < 40.228 && latitudes.max() > 40.269)
        assertTrue(longitudes.min() < -75.191 && longitudes.max() > -75.157)
        // Both clusters are represented, not just the wider US202 corridor.
        assertTrue(bounds.any { it.latitude > 40.245 && it.latitude < 40.249 })
    }

    @Test
    fun `per-trail bounds cover only that trail`() {
        val bounds = repository.getBoundsForTrail(1002)
        assertEquals(54, bounds.size)
        assertTrue(bounds.all { it.latitude > 40.246 && it.latitude < 40.248 })
        assertTrue(repository.getBoundsForTrail(999999).isEmpty())
    }

    @Test
    fun `groups landmarks by location in locations order`() {
        val grouped = repository.getLandmarksByLocation()
        assertEquals(listOf("Lions Pride Park", "US202 to Bradford Dam"), grouped.map { it.first.name })
        assertEquals(23, grouped[0].second.size)
        assertEquals(17, grouped[1].second.size)
        assertEquals(40, grouped.sumOf { it.second.size })
    }

    @Test
    fun `yields one beacon region per location`() {
        assertEquals(
            listOf(
                BeaconRegion("035a0617-0875-4cc7-a29c-be0caa8f557c", 17),
                BeaconRegion("035a0617-0875-4cc7-a29c-be0caa8f557c", 20),
            ),
            repository.getBeaconRegions(),
        )
    }
}
