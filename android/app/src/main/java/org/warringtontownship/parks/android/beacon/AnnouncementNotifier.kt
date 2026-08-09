package org.warringtontownship.parks.android.beacon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import org.warringtontownship.parks.android.MainActivity
import org.warringtontownship.parks.android.R
import org.warringtontownship.parks.android.data.model.Landmark
import javax.inject.Inject
import javax.inject.Singleton

data class AnnouncementText(val title: String, val body: String)

/**
 * What the user hears. The body deliberately matches what the visible sheet shows,
 * so a sighted companion reading the screen and a TalkBack user hearing it get the
 * same words.
 */
internal fun announcementText(landmark: Landmark, simplifiedText: Boolean): AnnouncementText =
    AnnouncementText(
        title = landmark.name,
        body = if (simplifiedText) landmark.description else landmark.longDescription,
    )

const val CHANNEL_LANDMARK_ALERTS = "landmark_alerts"
const val CHANNEL_TRAIL_SCANNING = "trail_scanning"

/**
 * The only place that talks to Android's notification system.
 *
 * Landmark alerts carry the full description in BigTextStyle rather than a
 * one-line summary, because TalkBack reads what the notification contains and a
 * truncated line would defeat the point: this is the channel that reaches a user
 * whose phone is in a pocket.
 */
@Singleton
class AnnouncementNotifier @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val manager = NotificationManagerCompat.from(context)

    fun createChannels() {
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_LANDMARK_ALERTS,
                "Landmark alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Announces a point of interest when you reach it"
            }
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_TRAIL_SCANNING,
                "Trail scanning",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while the app is listening for trail landmarks"
            }
        )
    }

    fun notifyLandmark(text: AnnouncementText) {
        val notification = NotificationCompat.Builder(context, CHANNEL_LANDMARK_ALERTS)
            .setSmallIcon(R.drawable.poi_marker)
            .setContentTitle(text.title)
            .setContentText(text.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text.body))
            .setContentIntent(contentIntent())
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .build()
        // A denied POST_NOTIFICATIONS permission makes this a no-op rather than a
        // crash; in-app announcements still reach the user.
        if (manager.areNotificationsEnabled()) {
            manager.notify(LANDMARK_NOTIFICATION_ID, notification)
        }
    }

    fun scanningNotification(): Notification =
        NotificationCompat.Builder(context, CHANNEL_TRAIL_SCANNING)
            .setSmallIcon(R.drawable.poi_marker)
            .setContentTitle("Listening for trail landmarks")
            .setContentText("You'll hear about points of interest as you reach them.")
            .setContentIntent(contentIntent())
            .setOngoing(true)
            .setSilent(true)
            .build()

    private fun contentIntent(): PendingIntent =
        PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        const val SCANNING_NOTIFICATION_ID = 1001
        private const val LANDMARK_NOTIFICATION_ID = 1002
    }
}
