package org.warringtontownship.us202.android.data.repository

import org.warringtontownship.us202.android.data.model.ConnectorData
import org.warringtontownship.us202.android.data.model.Coordinates
import org.warringtontownship.us202.android.data.model.Landmark
import org.warringtontownship.us202.android.data.model.Trail
import org.warringtontownship.us202.android.data.network.ConnectorApiService
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TrailRepository @Inject constructor(
    private val apiService: ConnectorApiService,
) {
    private var data: ConnectorData? = null
    private val loadMutex = Mutex()

    // Loads once per process; every ViewModel calls this in its init, so without the
    // guard the same JSON is fetched three times (and racing loads clobber each other).
    // A failed load stays null, so later screens retry.
    suspend fun loadData() {
        if (data != null) return
        loadMutex.withLock {
            if (data == null) {
                data = apiService.getConnectorData()
            }
        }
    }

    fun getFirstTrail(): Trail? = data?.trails?.firstOrNull()

    fun getBeaconUUID(): String? = data?.site?.beaconUUID

    fun getBeaconMajorCode(): Int? = data?.site?.beaconMajorCode

    fun getTrails(): List<Trail> = data?.trails ?: emptyList()

    fun getTrailById(id: Int): Trail? = data?.trails?.find { it.id == id }

    fun getLandmarks(): List<Landmark> = data?.landmarks ?: emptyList()

    fun getLandmarkById(id: Int): Landmark? = data?.landmarks?.find { it.id == id }

    fun getBoundary(): List<Coordinates> = data?.site?.boundaryCoordinates ?: emptyList()
}
