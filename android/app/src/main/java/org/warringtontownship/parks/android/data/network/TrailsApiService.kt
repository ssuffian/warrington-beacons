package org.warringtontownship.parks.android.data.network

import org.warringtontownship.parks.android.data.model.TrailsData
import retrofit2.http.GET

interface TrailsApiService {
    @GET("talking-trails.kml")
    suspend fun getTrailKml(): okhttp3.ResponseBody

    @GET("warrington-trails.json")
    suspend fun getTrailsData(): TrailsData
}
