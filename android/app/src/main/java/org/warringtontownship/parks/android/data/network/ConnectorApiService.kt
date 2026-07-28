package org.warringtontownship.parks.android.data.network

import org.warringtontownship.parks.android.data.model.ConnectorData
import retrofit2.http.GET

interface ConnectorApiService {
    @GET("us202trail-v2.json")
    suspend fun getConnectorData(): ConnectorData
}
