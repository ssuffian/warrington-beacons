package org.warringtontownship.parks.android.data.model

import java.io.StringReader
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element
import org.xml.sax.InputSource

/** Background map geometry only. KML Point placemarks never create app landmarks. */
object KmlRoutes {
    fun parse(xml: String): List<List<Coordinates>> {
        require(!xml.contains("<!DOCTYPE", ignoreCase = true)) { "KML DTDs are not supported" }
        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
            isExpandEntityReferences = false
        }
        val builder = factory.newDocumentBuilder()
        builder.setEntityResolver { _, _ -> InputSource(StringReader("")) }
        val doc = builder.parse(InputSource(StringReader(xml)))
        val routes = mutableListOf<List<Coordinates>>()
        for (tag in listOf("LineString", "outerBoundaryIs")) {
            val elements = doc.getElementsByTagNameNS("http://www.opengis.net/kml/2.2", tag)
            for (i in 0 until elements.length) {
                val coordinates = (elements.item(i) as Element)
                    .getElementsByTagNameNS("http://www.opengis.net/kml/2.2", "coordinates")
                for (j in 0 until coordinates.length) {
                    val points = coordinates.item(j).textContent.trim().split(Regex("\\s+")).map { tuple ->
                        val parts = tuple.split(',')
                        require(parts.size >= 2) { "Invalid KML coordinate" }
                        val lon = parts[0].toDouble()
                        val lat = parts[1].toDouble()
                        require(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0)
                        Coordinates(lat, lon)
                    }
                    require(points.size >= 2) { "A route needs at least two coordinates" }
                    routes.add(points)
                }
            }
        }
        require(routes.isNotEmpty()) { "KML has no route geometry" }
        return routes
    }
}
