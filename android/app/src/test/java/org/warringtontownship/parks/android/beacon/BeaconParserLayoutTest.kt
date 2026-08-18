package org.warringtontownship.parks.android.beacon

import org.altbeacon.beacon.BeaconParser
import org.junit.Assert.assertTrue
import org.junit.Test

class BeaconParserLayoutTest {

    @Test
    fun `scans for altbeacon layout`() {
        assertTrue(scannedBeaconLayouts().contains(BeaconParser.ALTBEACON_LAYOUT))
    }

    @Test
    fun `scans for ibeacon layout`() {
        // The Lions Pride beacons advertise in iBeacon format (the original
        // LionsPride iOS app ranges them via CoreLocation, which only understands
        // iBeacon frames). Without this parser the Android scanner never sees them.
        assertTrue(
            scannedBeaconLayouts().contains("m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24"),
        )
    }
}
