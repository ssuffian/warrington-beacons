package org.warringtontownship.parks.android.beacon

import org.junit.Assert.assertEquals
import org.junit.Test
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.data.model.Landmark

class AnnouncementTextTest {

    private val landmark = Landmark(
        id = 1002,
        location = "lions-pride-park",
        imagePath = "lions-pride-park/images/Yellow_trail.jpg",
        coordinates = Coordinates(40.24613, -75.177778),
        name = "Yellow Trail",
        category = "Trail",
        description = "A paved loop around the park.",
        longDescription = "The yellow trail is a 0.4-mile paved loop around the park and connects with the trail around IPW.",
        imageAlt = "Picture of Yellow Trail",
    )

    @Test
    fun `the title is always the landmark name`() {
        assertEquals("Yellow Trail", announcementText(landmark, simplifiedText = false).title)
        assertEquals("Yellow Trail", announcementText(landmark, simplifiedText = true).title)
    }

    @Test
    fun `simplified text speaks the short description`() {
        assertEquals(
            "A paved loop around the park.",
            announcementText(landmark, simplifiedText = true).body,
        )
    }

    @Test
    fun `full text speaks the long description, matching the visible sheet`() {
        assertEquals(landmark.longDescription, announcementText(landmark, simplifiedText = false).body)
    }
}
