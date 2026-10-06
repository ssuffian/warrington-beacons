package org.warringtontownship.parks.android.navigation

import android.net.Uri

object NavRoutes {
    // Tab graph routes
    const val PARK_MAP_GRAPH = "park_map_graph"
    const val LANDMARKS_GRAPH = "landmarks_graph"
    const val TRAIL_TOURS_GRAPH = "trail_tours_graph"
    const val ABOUT_GRAPH = "about_graph"
    const val SETTINGS_GRAPH = "settings_graph"

    // Park Map
    const val PARK_MAP = "park_map"
    const val PARK_MAP_DETAIL = "park_map_detail/{markerId}"
    fun parkMapDetail(markerId: String) = "park_map_detail/${Uri.encode(markerId)}"

    // Landmarks
    const val LANDMARKS = "landmarks"

    // Trail Tours
    const val TRAIL_TOURS = "trail_tours"
    const val TRAIL_DETAIL = "trail_detail/{trailId}"
    fun trailDetail(trailId: String) = "trail_detail/${Uri.encode(trailId)}"
    // startLandmarkId is optional: absent means begin at the trail's start (or end,
    // when reversed) rather than at a chosen stop.
    const val TRAIL_TOUR = "trail_tour/{trailId}/{reverse}?startLandmarkId={startLandmarkId}"
    fun trailTour(trailId: String, reverse: Boolean, startLandmarkId: String?) =
        "trail_tour/${Uri.encode(trailId)}/$reverse" +
            (startLandmarkId?.let { "?startLandmarkId=${Uri.encode(it)}" } ?: "")

    // About
    const val ABOUT = "about"

    // Settings
    const val SETTINGS = "settings"
    const val SETTINGS_DETAIL = "settings_detail/{settingKey}"
    fun settingsDetail(settingKey: String) = "settings_detail/$settingKey"
}
