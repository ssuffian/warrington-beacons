package org.warringtontownship.parks.android.beacon

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import org.warringtontownship.parks.android.data.model.Landmark
import org.warringtontownship.parks.android.data.prefs.AppPreferences
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Turns raw beacon detections into "the user has arrived at this landmark", and
 * tells them about it.
 *
 * Screens consume [currentLandmark] rather than the scanner's raw closest-beacon
 * value, so the debounce rules in [AnnouncementGate] govern the map sheet and the
 * tour's auto-advance too, not just the spoken announcement.
 *
 * Announcing is separately conditional on the user's setting: a Trail Tour still
 * advances silently when announcements are off, because auto-advance is navigation
 * the user asked for rather than the app talking to them.
 */
@Singleton
class LandmarkAnnouncer @Inject constructor(
    private val beaconScanner: BeaconScanner,
    private val trailRepository: TrailRepository,
    private val notifier: AnnouncementNotifier,
    private val appPreferences: AppPreferences,
) {
    private val gate = AnnouncementGate(clock = { System.currentTimeMillis() })

    // Owned by the singleton rather than borrowed from a caller: a ViewModel's
    // viewModelScope dies with that screen, but this collector must outlive any
    // single screen for as long as the process is alive.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _currentLandmark = MutableSharedFlow<Landmark>(replay = 1)
    val currentLandmark: SharedFlow<Landmark> = _currentLandmark.asSharedFlow()

    init {
        scope.launch {
            beaconScanner.detectedBeacons.collect { detections ->
                val closest = detections.minByOrNull { it.distance }
                if (closest == null) {
                    // A momentary empty ranging cycle is routine BLE flicker, not a
                    // reason to forget the cooldown and last-announced landmark —
                    // only clear the in-progress sighting counts.
                    gate.clearSightings()
                    return@collect
                }
                if (!gate.shouldAnnounce(closest.minorCode, closest.distance)) return@collect
                val landmark = trailRepository.getLandmarkById(closest.minorCode)
                if (landmark == null) {
                    Log.w("LandmarkAnnouncer", "No landmark for minor ${closest.minorCode}")
                    return@collect
                }
                _currentLandmark.emit(landmark)
                if (appPreferences.announcementsEnabled.value) {
                    notifier.notifyLandmark(textFor(landmark))
                }
            }
        }
    }

    fun textFor(landmark: Landmark): AnnouncementText =
        announcementText(landmark, appPreferences.simplifiedText.value)
}
