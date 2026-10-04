package org.warringtontownship.parks.android.ui.trailtours

import org.warringtontownship.parks.android.data.model.Trail
import org.warringtontownship.parks.android.data.model.TrailCoordinate
import org.warringtontownship.parks.android.data.model.TrailEndpoint
import org.warringtontownship.parks.android.ui.common.TrailMapMarker

/*
 * Pure tour-ordering rules shared by the trail detail and tour screens, kept out of
 * Compose so they are unit-testable. API v3 lists a trail's stops in tour order inside
 * boundaryCoordinates and may add beacon-free start/end points around them.
 */

internal const val TRAIL_START_TITLE = "Trail start"
internal const val TRAIL_END_TITLE = "Trail end"

/** Map-marker IDs for the endpoints; the leading ':' can never match a landmark recordKey. */
internal const val TRAIL_START_MARKER_ID = ":trail-start"
internal const val TRAIL_END_MARKER_ID = ":trail-end"

internal fun tourStops(trail: Trail): List<TrailCoordinate> =
    trail.boundaryCoordinates.filter { it.landmarkId != null }

/** What comes after the current stop in the chosen direction. */
internal sealed interface TourNext {
    data class Stop(val index: Int) : TourNext
    data object TrailStart : TourNext
    data object TrailEnd : TourNext
}

/**
 * Forward past the last stop leads to the trail end when one exists; reversed past
 * the first stop leads to the trail start. Without an endpoint the existing
 * wrap-around preview is kept.
 */
internal fun nextInTour(
    stopCount: Int,
    currentIndex: Int,
    reverse: Boolean,
    hasStart: Boolean,
    hasEnd: Boolean,
): TourNext {
    require(stopCount > 0) { "a tour needs at least one stop" }
    return if (reverse) {
        when {
            currentIndex > 0 -> TourNext.Stop(currentIndex - 1)
            hasStart -> TourNext.TrailStart
            else -> TourNext.Stop(stopCount - 1)
        }
    } else {
        when {
            currentIndex < stopCount - 1 -> TourNext.Stop(currentIndex + 1)
            hasEnd -> TourNext.TrailEnd
            else -> TourNext.Stop((currentIndex + 1) % stopCount)
        }
    }
}

/**
 * The stop a tour opens on. A chosen stop wins; with none chosen (the tour begins at
 * the trail's start or end), forward opens on the first stop and reverse on the last.
 */
internal fun initialTourIndex(
    stops: List<TrailCoordinate>,
    startLandmarkId: String?,
    reverse: Boolean,
): Int {
    if (stops.isEmpty()) return 0
    val chosen = startLandmarkId?.let { id -> stops.indexOfFirst { it.landmarkId == id } } ?: -1
    return when {
        chosen >= 0 -> chosen
        startLandmarkId == null && reverse -> stops.size - 1
        else -> 0
    }
}

/** A trail endpoint a tour can begin from in the given direction. */
internal data class TourTrailhead(val title: String, val endpoint: TrailEndpoint)

/**
 * Forward tours begin at the trail start and reverse tours at the trail end, when the
 * data supplies them. Null means fall back to choosing a stop.
 */
internal fun trailheadFor(trail: Trail, reverse: Boolean): TourTrailhead? =
    if (reverse) {
        trail.end?.let { TourTrailhead(TRAIL_END_TITLE, it) }
    } else {
        trail.start?.let { TourTrailhead(TRAIL_START_TITLE, it) }
    }

/** Distinct, non-tappable map markers for the trail's start and end, when present. */
internal fun endpointMarkers(trail: Trail): List<TrailMapMarker> = listOfNotNull(
    trail.start?.let {
        TrailMapMarker(TRAIL_START_MARKER_ID, TRAIL_START_TITLE, "", it.latitude, it.longitude, isEndpoint = true)
    },
    trail.end?.let {
        TrailMapMarker(TRAIL_END_MARKER_ID, TRAIL_END_TITLE, "", it.latitude, it.longitude, isEndpoint = true)
    },
)
