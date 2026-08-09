package org.warringtontownship.parks.android.data.repository

import kotlinx.coroutines.sync.Mutex
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
    private val loadMutex = Mutex()

    // Loads once per process; every ViewModel calls this in its init, so without the
    // guard the same JSON is fetched three times (and racing loads clobber each other).
    // A failed load stays null, so later screens retry.
    suspend fun loadData() {
        if (data != null) return
        loadMutex.withLock {
            if (data == null) {
                data = apiService.getTrailsData()
            }
        }
    }

    fun getLandmarks(): List<Landmark> = data?.landmarks ?: emptyList()

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
            getTrails().flatMap { trail ->
                trail.boundaryCoordinates.map { Coordinates(it.latitude, it.longitude) }
            }

    fun getBoundsForTrail(trailId: Int): List<Coordinates> =
        getTrailById(trailId)?.boundaryCoordinates
            ?.map { Coordinates(it.latitude, it.longitude) }
            ?: emptyList()

    fun getBeaconRegions(): List<BeaconRegion> {
        val uuid = data?.beaconUUID ?: return emptyList()
        return getLocations().map { BeaconRegion(uuid, it.beaconMajorCode) }.distinct()
    }

    private companion object {
        const val IMAGE_BASE_URL = "https://trails.warringtoneac.org/"
    }
}
