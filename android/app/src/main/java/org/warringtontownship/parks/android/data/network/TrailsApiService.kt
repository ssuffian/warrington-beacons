package org.warringtontownship.parks.android.data.network

import org.warringtontownship.parks.android.data.model.TrailsData
import retrofit2.http.GET

object TrailsApiContract {
    const val VERSION = "v3"
    const val DATA_PATH = "api/$VERSION/trails.json"
    const val KML_PATH = "api/$VERSION/talking-trails.kml"
}

interface TrailsApiService {
    @GET(TrailsApiContract.KML_PATH)
    suspend fun getTrailKml(): okhttp3.ResponseBody

    @GET(TrailsApiContract.DATA_PATH)
    suspend fun getTrailsData(): TrailsData
}
