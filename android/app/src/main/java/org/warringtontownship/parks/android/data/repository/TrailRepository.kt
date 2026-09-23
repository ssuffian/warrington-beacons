package org.warringtontownship.parks.android.data.repository

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.warringtontownship.parks.android.data.model.KmlRoutes
import kotlinx.coroutines.sync.withLock
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.data.model.Landmark
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.model.Trail
import org.warringtontownship.parks.android.data.model.TrailsData
import org.warringtontownship.parks.android.data.network.TrailsApiService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The one class that knows the data covers more than one location. Screens see a
 * single flat set of landmarks and trails; only the Trail Tours list and beacon
 * scanning ask about locations.
 */
@Singleton
class TrailRepository @Inject constructor(
    private val apiService: TrailsApiService,
) {
    private var data: TrailsData? = null
    private var mapRoutes: List<List<Coordinates>>? = null
    private val loadMutex = Mutex()

    // Loads once per process; every ViewModel calls this in its init, so without the
    // guard the same JSON is fetched three times (and racing loads clobber each other).
    // A failed load stays null, so later screens retry.
    suspend fun loadData() {
        if (data != null) return
        loadMutex.withLock {
            if (data == null) {
                val loaded = apiService.getTrailsData()
                mapRoutes = try {
                    val xml = apiService.getTrailKml().use { it.string() }
                    withContext(Dispatchers.Default) { KmlRoutes.parse(xml) }
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    // Before the KML is deployed, or offline without a cache, keep
                    // the existing JSON routes available. Never lose landmark text.
                    null
                }
                data = loaded
            }
        }
    }

    fun getLandmarks(): List<Landmark> = data?.landmarks ?: emptyList()

    fun getMapRoutes(): List<List<Coordinates>> = mapRoutes ?: getTrails().map { trail ->
        trail.boundaryCoordinates.map { Coordinates(it.latitude, it.longitude) }
    }

    fun getLandmarkById(id: Int): Landmark? = data?.landmarks?.find { it.id == id }

    fun getTrails(): List<Trail> = data?.trails ?: emptyList()

    fun getTrailById(id: Int): Trail? = data?.trails?.find { it.id == id }

    fun getLocations(): List<Location> = data?.locations ?: emptyList()

    fun getTrailsByLocation(): List<Pair<Location, List<Trail>>> =
        getLocations().map { location ->
            location to getTrails().filter { it.location == location.id }
        }

    fun getLandmarksByLocation(): List<Pair<Location, List<Landmark>>> =
        getLocations().map { location ->
            location to getLandmarks().filter { it.location == location.id }
        }

    fun imageUrlFor(landmark: Landmark): String = IMAGE_BASE_URL + landmark.imagePath

    fun getCombinedBounds(): List<Coordinates> =
        getLandmarks().map { it.coordinates } +
            getMapRoutes().flatten()

    fun getBoundsForTrail(trailId: Int): List<Coordinates> =
        getTrailById(trailId)?.boundaryCoordinates
            ?.map { Coordinates(it.latitude, it.longitude) }
            ?: emptyList()

    fun getBeaconRegions(): List<BeaconRegion> {
        if (data == null) return emptyList()
        // Range each location's major under both of its advertisement UUIDs — a
        // beacon's iBeacon and AltBeacon frames may carry different UUIDs (see
        // Location), and the parser layout that decodes a frame decides which one
        // shows up. distinct() collapses the duplicate when the two UUIDs match.
        return getLocations().flatMap { location ->
            listOf(
                BeaconRegion(location.iBeaconUUID, location.beaconMajorCode),
                BeaconRegion(location.altBeaconUUID, location.beaconMajorCode),
            )
        }.distinct()
    }

    private companion object {
        const val IMAGE_BASE_URL = "https://trails.warringtoneac.org/"
    }
}
