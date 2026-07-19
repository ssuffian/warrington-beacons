package org.warringtontownship.us202.android.data.model

data class ConnectorData(
    val site: Site,
    val landmarks: List<Landmark>,
    val trails: List<Trail>,
)

data class Site(
    val boundaryCoordinates: List<Coordinates>,
    val beaconUUID: String,
    val beaconMajorCode: Int,
)

data class Coordinates(
    val latitude: Double,
    val longitude: Double,
)

data class Landmark(
    val coordinates: Coordinates,
    val id: Int,
    val name: String,
    val category: String,
    val description: String,
    val longDescription: String,
    val imageName: String,
    val imageAlt: String,
    val isOpen: Boolean? = null,
    val trailDistanceDescription: String? = null,
)

data class Trail(
    val name: String,
    val id: Int,
    val isOpen: Boolean,
    val trailDistanceDescription: String,
    val boundaryCoordinates: List<TrailCoordinate>,
)

data class TrailCoordinate(
    val latitude: Double,
    val longitude: Double,
    val distanceToNextCounterClockwise: String? = null,
    val distanceToNextCounterClockwiseDescription: String? = null,
    val distanceToNextClockwise: String? = null,
    val distanceToNextClockwiseDescription: String? = null,
    val landmarkId: Int? = null,
)
