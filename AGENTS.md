# Repository instructions

## iOS TestFlight releases

The iOS app updates the existing Lions Pride Park App Store record, not a new
listing. Keep bundle ID `org.warringtontownship.lionspride`, Apple team
`ZA7MADZY65`, and App Store ID `1532727572`. Do not upload the combined app under
the earlier personal-team identifier `org.warringtoneac.talkingtrails`.

Use the documented command-line release workflow in `ios/APP_STORE_RELEASE.md`.
This Apple team uses Xcode's automatic App Store signing during
`xcodebuild -exportArchive`; a local `Apple Distribution` keychain identity is
not required.

Use command-line tools and local signing data for build, signing, upload, and
verification work. Do not open Xcode or a web browser unless the user explicitly
asks for interactive work in one of those applications.

Create an unsigned Release archive with `CODE_SIGNING_ALLOWED=NO`, then export
or upload it with `-allowProvisioningUpdates` and the appropriate plist in
`ios/`. Do not first attempt a normally signed archive, open Xcode, ask the user
to create a distribution certificate, or infer that signing assets disappeared
because `security find-identity` has no `Apple Distribution` entry. That path
selects development signing and can fail with the misleading “team has no
devices” error.

Before uploading, increment `CURRENT_PROJECT_VERSION` in both app target build
configurations, verify the archive's `CFBundleVersion`, and run the relevant
build/tests. Uploading is an external release action; only perform it when the
user requested the TestFlight upload.

## Master data and map releases

Treat `server/talking-trails.kml` as the sole source of geographic truth. Point
coordinates, route shapes, tour membership (`trailId`) and tour sequence
(`stopOrder`) belong in KML so they can be maintained in Google Earth. Never add
those fields back to the master spreadsheet.

Treat the master Sheet as the source of text, images, beacon IDs/status,
location configuration and directional instructions. Join a Sheet row to a KML
Point only with the stable `recordKey`; join Trails to route placemarks with
`kmlTrailGroupId`/`trailGroupId`. Do not guess a link from name or proximity.

Do not make either mobile app download live Sheet tabs independently. Generate
and validate the single atomic `server/warrington-trails.json` with
`scripts/master_sheet.py`; both apps already consume that file. A validation
failure must stop the app-data update and preserve the last successful app data.
Static website assets may still deploy with that preserved data.

Pin released apps to a major data contract under `server/api/vN/`. Keep v1 and
the unversioned legacy URLs available for installed builds. Publish the unified
string Trail ID contract as v2 only after its generator, fixtures and both apps
are ready. Never repoint a released app to a moving `latest` endpoint, and never
overwrite an older major version with a breaking schema.

Never publish spreadsheet edits automatically or regenerate served JSON during
an ordinary site deployment. Use the manually started **Prepare trail data
release** workflow to validate an existing API major and open a review pull
request. The committed snapshot is published only after that pull request is
reviewed and merged. Add a new major version to the workflow only after its
generator, fixtures, both apps and `server/api/versions.json` are ready.

Use full `https://trails.warringtoneac.org/...` URLs in the Sheet's `imagePath`
cells so editors can open them directly. `scripts/master_sheet.py` must normalize
those URLs to server-relative paths in app JSON to preserve compatibility with
installed builds. Generate the browsable `/images/` catalog with
`scripts/build_image_library.py`; do not hand-maintain its cards.

Keep the served KML link on the first Guide tab of any master workbook intended
for outside editors. Exclude old-source reconciliation columns and the completed
Decisions tab from that editor workbook, but retain `recordKey`,
`kmlTrailGroupId`, beacon placement/status fields and review controls because
they support the KML join and field maintenance. Exclude `macAddress`; neither
mobile app nor the JSON generator uses it.

Use the command-line workflows documented in `docs/master-sheet.md`. Do not open
Xcode or Google Earth merely to inspect or build files; use them only when the
user explicitly wants interactive editing in those apps.
