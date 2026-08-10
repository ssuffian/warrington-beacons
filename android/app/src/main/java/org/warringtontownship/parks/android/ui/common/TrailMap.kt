package org.warringtontownship.parks.android.ui.common

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import org.osmdroid.config.Configuration
import org.osmdroid.events.MapListener
import org.osmdroid.events.ScrollEvent
import org.osmdroid.events.ZoomEvent
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.CopyrightOverlay
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import org.warringtontownship.parks.android.R
import org.warringtontownship.parks.android.data.model.Coordinates
import java.io.File

data class TrailMapMarker(
    val id: Int,
    val title: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
)

/**
 * How much ground the map has to be showing before every landmark is drawn.
 *
 * The two locations together span ~5.7 km, and at that scale Lions Pride Park's 23
 * landmarks land inside ~58x93 px — one unreadable, untappable pile. Below this span
 * the markers have separated enough to be individually usable.
 */
internal const val DETAIL_SPAN_METERS = 700.0

private const val METERS_PER_DEGREE_LATITUDE = 111_320.0

/**
 * Which markers to draw for the currently visible span. Zoomed out past
 * [DETAIL_SPAN_METERS], only trailheads are drawn, so each location reads as a
 * single tappable pin instead of a blob. Callers showing a single trail's stops pass
 * `collapseWhenZoomedOut = false`, since those stops are mostly points of interest
 * and collapsing them would empty the map.
 */
internal fun visibleMarkersFor(
    markers: List<TrailMapMarker>,
    visibleSpanMeters: Double,
    collapseWhenZoomedOut: Boolean,
): List<TrailMapMarker> =
    if (collapseWhenZoomedOut && visibleSpanMeters > DETAIL_SPAN_METERS) {
        markers.filter { it.category == "Trail" }
    } else {
        markers
    }

private fun initOsmdroid(context: Context) {
    Configuration.getInstance().apply {
        // OSM tile policy requires an identifying user agent.
        userAgentValue = context.packageName
        osmdroidBasePath = File(context.filesDir, "osmdroid")
        // Tiles viewed online are cached here and served automatically when offline.
        osmdroidTileCache = File(context.cacheDir, "osmdroid_tiles")
    }
}

@Composable
fun TrailMap(
    routes: List<List<Coordinates>>,
    markers: List<TrailMapMarker>,
    boundsCoordinates: List<Coordinates>,
    modifier: Modifier = Modifier,
    onMarkerClick: ((Int) -> Unit)? = null,
    focusPosition: Coordinates? = null,
    centerZoomPosition: Coordinates? = null,
    centerZoomLevel: Float = 18f,
    highlightedMarkerId: Int? = null,
    collapseMarkersWhenZoomedOut: Boolean = false,
    onLocationPermissionResult: (() -> Unit)? = null,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    var locationPermissionGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = { granted ->
            locationPermissionGranted = granted
            // The beacon foreground service needs this same location grant on Android
            // 14+. Without telling anyone the answer arrived, a screen that started
            // scanning before the user answered would stay degraded until they left and
            // came back.
            onLocationPermissionResult?.invoke()
        },
    )
    LaunchedEffect(Unit) {
        if (!locationPermissionGranted) {
            permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    val mapView = remember {
        initOsmdroid(context)
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            zoomController.setVisibility(CustomZoomButtonsController.Visibility.SHOW_AND_FADEOUT)
            minZoomLevel = 10.0
            maxZoomLevel = 20.0
            controller.setZoom(14.0)
            controller.setCenter(GeoPoint(40.248831, -75.174176))
        }
    }
    val locationOverlay = remember {
        MyLocationNewOverlay(GpsMyLocationProvider(context), mapView)
    }

    // Drives marker collapsing. Starts unknown (= collapsed) so the very first frame is
    // readable; every zoom or scroll refreshes it.
    var visibleSpanMeters by remember { mutableStateOf(Double.MAX_VALUE) }
    val refreshVisibleSpan = {
        visibleSpanMeters = mapView.boundingBox.latitudeSpan * METERS_PER_DEGREE_LATITUDE
    }
    DisposableEffect(mapView) {
        val listener = object : MapListener {
            override fun onScroll(event: ScrollEvent?): Boolean {
                refreshVisibleSpan()
                return false
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                refreshVisibleSpan()
                return false
            }
        }
        mapView.addMapListener(listener)
        onDispose { mapView.removeMapListener(listener) }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            locationOverlay.disableMyLocation()
            mapView.onDetach()
        }
    }

    LaunchedEffect(locationPermissionGranted) {
        if (locationPermissionGranted) {
            locationOverlay.enableMyLocation()
        }
    }

    LaunchedEffect(boundsCoordinates) {
        if (boundsCoordinates.size >= 2) {
            val bounds = BoundingBox.fromGeoPoints(
                boundsCoordinates.map { GeoPoint(it.latitude, it.longitude) }
            )
            val fit = {
                mapView.zoomToBoundingBox(bounds.increaseByScale(1.2f), false)
                refreshVisibleSpan()
            }
            if (mapView.width > 0) fit() else mapView.addOnFirstLayoutListener { _, _, _, _, _ -> fit() }
        }
    }

    var isInitialLoad by remember { mutableStateOf(true) }
    LaunchedEffect(focusPosition) {
        if (isInitialLoad) {
            isInitialLoad = false
            return@LaunchedEffect
        }
        if (focusPosition != null) {
            val visible = mapView.boundingBox
                .contains(focusPosition.latitude, focusPosition.longitude)
            if (!visible) {
                mapView.controller.animateTo(GeoPoint(focusPosition.latitude, focusPosition.longitude))
            }
        }
    }

    LaunchedEffect(centerZoomPosition) {
        if (centerZoomPosition != null) {
            mapView.controller.animateTo(
                GeoPoint(centerZoomPosition.latitude, centerZoomPosition.longitude),
                centerZoomLevel.toDouble(),
                500L,
            )
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { mapView },
        update = { view ->
            view.overlays.clear()
            view.overlays.add(CopyrightOverlay(context))

            routes.filter { it.isNotEmpty() }.forEach { route ->
                view.overlays.add(Polyline(view).apply {
                    setPoints(route.map { GeoPoint(it.latitude, it.longitude) })
                    outlinePaint.color = Color.BLUE
                    outlinePaint.strokeWidth = 8f
                    infoWindow = null
                })
            }

            visibleMarkersFor(markers, visibleSpanMeters, collapseMarkersWhenZoomedOut).forEach { marker ->
                val iconRes = when {
                    marker.id == highlightedMarkerId -> R.drawable.current_marker
                    marker.category == "Trail" -> R.drawable.trailhead_marker
                    else -> R.drawable.poi_marker
                }
                view.overlays.add(Marker(view).apply {
                    position = GeoPoint(marker.latitude, marker.longitude)
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    icon = ContextCompat.getDrawable(context, iconRes)
                    title = marker.title
                    infoWindow = null
                    setOnMarkerClickListener { _, _ ->
                        onMarkerClick?.invoke(marker.id)
                        onMarkerClick != null
                    }
                })
            }

            view.overlays.add(locationOverlay)
            view.invalidate()
        },
    )
}
