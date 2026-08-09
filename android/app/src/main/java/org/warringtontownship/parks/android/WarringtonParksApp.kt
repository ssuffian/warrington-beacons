package org.warringtontownship.parks.android

import android.app.Application
import dagger.hilt.android.HiltAndroidApp
import org.warringtontownship.parks.android.beacon.AnnouncementNotifier
import javax.inject.Inject

@HiltAndroidApp
class WarringtonParksApp : Application() {

    @Inject
    lateinit var announcementNotifier: AnnouncementNotifier

    override fun onCreate() {
        super.onCreate()
        announcementNotifier.createChannels()
    }
}
