package org.warringtontownship.parks.android.beacon

import android.util.Log
import kotlinx.coroutines.CoroutineScope
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

    private val _currentLandmark = MutableSharedFlow<Landmark>()
    val currentLandmark: SharedFlow<Landmark> = _currentLandmark.asSharedFlow()

    private var started = false

    /**
     * Begins observing detections. Called once from the first ViewModel that needs
     * announcements; the guard keeps repeat calls from stacking collectors, and the
     * scope outlives any single screen because this is a singleton.
     */
    fun start(scope: CoroutineScope) {
        if (started) return
        started = true
        scope.launch {
            beaconScanner.detectedBeacons.collect { detections ->
                val closest = detections.minByOrNull { it.distance }
                if (closest == null) {
                    gate.reset()
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
