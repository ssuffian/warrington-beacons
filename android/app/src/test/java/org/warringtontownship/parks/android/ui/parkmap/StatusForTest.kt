package org.warringtontownship.parks.android.ui.parkmap

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The status control is the only thing on the Park Map that tells a screen-reader
 * user whether the app is actually listening, so what it says under each
 * combination of failures — and which failure wins — is the behaviour worth
 * pinning down.
 */
class StatusForTest {

    private val off = "Announcements off."
    private val bluetoothOff = "Bluetooth is off — announcements paused"
    private val notificationsBlocked =
        "Notifications are blocked — landmarks will only be announced on screen"
    private val degraded = "Announcements on, but only while this screen is open."
    private val healthy = "Announcements on. Listening for nearby landmarks."

    private fun status(
        enabled: Boolean = true,
        bluetoothOn: Boolean = true,
        notificationsEnabled: Boolean = true,
        serviceFailed: Boolean = false,
    ) = statusFor(enabled, bluetoothOn, notificationsEnabled, serviceFailed)

    @Test
    fun `everything healthy reports listening`() {
        assertEquals(healthy, status())
    }

    @Test
    fun `a degraded service reports the screen-only limitation`() {
        assertEquals(degraded, status(serviceFailed = true))
    }

    @Test
    fun `bluetooth off is reported`() {
        assertEquals(bluetoothOff, status(bluetoothOn = false))
    }

    @Test
    fun `blocked notifications are reported`() {
        assertEquals(notificationsBlocked, status(notificationsEnabled = false))
    }

    @Test
    fun `the user's own choice to turn announcements off outranks every fault`() {
        assertEquals(
            off,
            status(
                enabled = false,
                bluetoothOn = false,
                notificationsEnabled = false,
                serviceFailed = true,
            ),
        )
    }

    @Test
    fun `bluetooth off outranks blocked notifications and a degraded service`() {
        assertEquals(
            bluetoothOff,
            status(bluetoothOn = false, notificationsEnabled = false, serviceFailed = true),
        )
    }

    @Test
    fun `blocked notifications outrank a degraded service`() {
        // Both are partial-function states, but a blocked notification is the one
        // the user can act on, and it explains the bigger gap: nothing reaches a
        // pocketed phone at all.
        assertEquals(
            notificationsBlocked,
            status(notificationsEnabled = false, serviceFailed = true),
        )
    }
}
