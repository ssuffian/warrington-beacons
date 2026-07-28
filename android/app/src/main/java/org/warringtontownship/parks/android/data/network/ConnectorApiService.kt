package org.warringtontownship.parks.android.data.network

import org.warringtontownship.parks.android.data.model.TrailsData
import retrofit2.http.GET

interface ConnectorApiService {
    @GET("warrington-trails.json")
    suspend fun getConnectorData(): TrailsData
}
