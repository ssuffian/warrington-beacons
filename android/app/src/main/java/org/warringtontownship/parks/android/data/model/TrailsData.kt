package org.warringtontownship.parks.android.data.model

data class TrailsData(
    val locations: List<Location>,
    val landmarks: List<Landmark>,
    val trails: List<Trail>,
)

data class Location(
    val id: String,
    val name: String,
    val address: String,
    val beaconMajorCode: Int,
    // UUIDs carried by this location's beacons' iBeacon and AltBeacon frames
    // (the hardware dual-advertises both). They may match (US-202) or differ
    // (Lions Pride AltBeacon frames use 00112233-…).
    val iBeaconUUID: String,
    val altBeaconUUID: String,
)

data class Coordinates(
    val latitude: Double,
    val longitude: Double,
)

data class Landmark(
    val id: Int,
    val location: String,
    val imagePath: String,
    val coordinates: Coordinates,
    val name: String,
    val category: String,
    val description: String,
    val longDescription: String,
    val imageAlt: String,
    val isOpen: Boolean? = null,
    val trailDistanceDescription: String? = null,
)

data class Trail(
    val id: Int,
    val location: String,
    val name: String,
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
