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
    // Stable recordKey shared by the master Sheet and KML (e.g. "LP-4"). API v3.
    val id: String,
    // Present only when a physical beacon broadcasts this place. A place without
    // one is still shown and can be a tour stop, but no beacon ever matches it.
    val beaconMinor: Int? = null,
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
    val id: String,
    val location: String,
    val name: String,
    val isOpen: Boolean,
    val trailDistanceDescription: String,
    val boundaryCoordinates: List<TrailCoordinate>,
    // Beacon-free trail start and end points (never landmarks). Both optional.
    val start: TrailEndpoint? = null,
    val end: TrailEndpoint? = null,
)

/**
 * A beacon-free trail start or end. [distance] and [directions] lead toward the
 * adjacent tour stop: from the start forward to the first stop, and from the end
 * back to the last stop.
 */
data class TrailEndpoint(
    val latitude: Double,
    val longitude: Double,
    val distance: String = "",
    val directions: String = "",
)

data class TrailCoordinate(
    val latitude: Double,
    val longitude: Double,
    val distanceToNextCounterClockwise: String? = null,
    val distanceToNextCounterClockwiseDescription: String? = null,
    val distanceToNextClockwise: String? = null,
    val distanceToNextClockwiseDescription: String? = null,
    val landmarkId: String? = null,
)
