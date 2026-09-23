package org.warringtontownship.parks.android.data

import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.warringtontownship.parks.android.data.model.KmlRoutes

class KmlRoutesTest {
    @Test fun `real KML uses routes and polygon boundaries but never point placemarks`() {
        val routes = KmlRoutes.parse(File("../../server/talking-trails.kml").readText())
        assertEquals(15, routes.size)
        assertTrue(routes.all { it.size >= 2 })
        assertTrue(routes.flatten().all { it.latitude in 40.0..41.0 && it.longitude in -76.0..-75.0 })
    }

    @Test fun `segments remain separate and coordinates use longitude latitude order`() {
        val routes = KmlRoutes.parse("""<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
          <Placemark><Point><coordinates>-75,40,0</coordinates></Point></Placemark>
          <Placemark><LineString><coordinates>-75.1,40.1,0 -75.2,40.2,0</coordinates></LineString></Placemark>
          <Placemark><LineString><coordinates>-75.3,40.3,0 -75.4,40.4,0</coordinates></LineString></Placemark>
        </Document></kml>""")
        assertEquals(2, routes.size)
        assertEquals(40.1, routes[0][0].latitude, 0.000001)
        assertEquals(-75.1, routes[0][0].longitude, 0.000001)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `reject external entity documents`() { KmlRoutes.parse("<!DOCTYPE kml><kml/>") }
}
