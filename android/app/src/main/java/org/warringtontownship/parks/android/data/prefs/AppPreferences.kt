package org.warringtontownship.parks.android.data.prefs

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The app's user settings, in one place. Exposed as flows because the announcements
 * toggle has to update the Park Map's status control as soon as it changes, and the
 * announcer reads Simplified Text from outside composition.
 */
@Singleton
class AppPreferences @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _simplifiedText = MutableStateFlow(prefs.getBoolean(KEY_SIMPLIFIED_TEXT, false))
    val simplifiedText: StateFlow<Boolean> = _simplifiedText.asStateFlow()

    // Defaults on: this is what the app already did, and silence should not need
    // opting in.
    private val _announcementsEnabled =
        MutableStateFlow(prefs.getBoolean(KEY_ANNOUNCEMENTS_ENABLED, true))
    val announcementsEnabled: StateFlow<Boolean> = _announcementsEnabled.asStateFlow()

    fun setSimplifiedText(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SIMPLIFIED_TEXT, enabled).apply()
        _simplifiedText.value = enabled
    }

    fun setAnnouncementsEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ANNOUNCEMENTS_ENABLED, enabled).apply()
        _announcementsEnabled.value = enabled
    }

    fun isWelcomeSeen(): Boolean = prefs.getBoolean(KEY_WELCOME_SEEN, false)

    fun setWelcomeSeen() {
        prefs.edit().putBoolean(KEY_WELCOME_SEEN, true).apply()
    }

    private companion object {
        const val PREFS_NAME = "warrington_prefs"
        const val KEY_SIMPLIFIED_TEXT = "simplified_text"
        const val KEY_ANNOUNCEMENTS_ENABLED = "announcements_enabled"
        const val KEY_WELCOME_SEEN = "welcome_seen"
    }
}
