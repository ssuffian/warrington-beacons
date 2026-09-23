# Warrington Talking Trails (iOS)

This target covers Lions Pride Park and the US-202 to Bradford Dam Trail. It is
configured as version 2.0 of the existing Lions Pride Park App Store listing
with bundle ID `org.warringtontownship.lionspride` and Warrington Township team
`ZA7MADZY65`. See [APP_STORE_RELEASE.md](APP_STORE_RELEASE.md) for the listing
copy and submission checklist.

[Design board](https://miro.com/app/board/o9J_kwUBUpw=/)

[Detailed designs](https://www.figma.com/file/ONRkvP6QbuoGe6SMOUXqeA/Lions-Pride-Park-1.1?node-id=0%3A1)

[Clickable prototype](https://www.figma.com/proto/ONRkvP6QbuoGe6SMOUXqeA/Lions-Pride-Park-1.1?node-id=1%3A2&scaling=scale-down)

[App Features Spreadsheet](https://docs.google.com/spreadsheets/d/1iLrylvD0EKTV7SilVe_5p2qohvlZvPJfdiBTh6oWUz4/edit?usp=sharing)

--

[JSON Data File](https://lions-pride-park-configuration.s3.us-east-2.amazonaws.com/lionsPrideData.json)
(legacy Lions Pride Park data — the AWS account is inaccessible; a
local copy is preserved in `server/lions-pride-park/` at the repo
root. The app now loads US202 data from
`https://trails.warringtoneac.org/us-202/`, set via `base_url_string`
in `WarringtonTalkingTrails/Info.plist`.)

[Google Sheet for updating data](https://docs.google.com/spreadsheets/d/1zaS5Gm6D1ukShIyJ1eN_7_A6c8kUTmqMx9ZZDJn6EvY)

[Backend Data Repo](https://github.com/chariotsolutions/lionspride-backend-data)

[Android Repo](https://github.com/chariotsolutions/lionspride-android)
