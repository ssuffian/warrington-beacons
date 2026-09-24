# Warrington Talking Trails — App Store release

This release updates the existing **Lions Pride Park** App Store listing under
the Warrington Township organization. It expands that app to include both Lions
Pride Park and the US-202 to Bradford Dam Trail and renames the installed app to
Warrington Talking Trails.

## App identity

- App Store name: `Warrington Talking Trails`
- Existing App Store ID: `1532727572`
- Bundle ID: `org.warringtontownship.lionspride`
- Apple Developer Team ID: `ZA7MADZY65`
- Version: `2.0`
- Build: `20260923.3`; increment for every subsequent upload
- Primary category: Travel
- Platform: iPhone
- Minimum OS: iOS 17.0

The bundle ID must remain exactly as shown because App Store updates are matched
by bundle ID. Signing uses the Warrington Township team and automatic signing.

## Product-page copy

The final copy-and-paste files and reviewed screenshots are in
[`AppStoreAssets`](AppStoreAssets/README.md). That package supersedes the draft
copy below.

Subtitle:

> Self-guided local trail tours

Promotional text:

> Explore Warrington's local trails with interactive maps, self-guided tours,
> landmark photos, and on-device beacon guidance.

Description:

> Explore Lions Pride Park and the US-202 to Bradford Dam Trail with maps,
> self-guided tours, and information about points of interest along the way.
>
> Warrington Talking Trails includes trail maps, photographs and descriptions
> for landmarks at both locations. Trail Tours show the distance to the next
> stop. With location and Bluetooth permission, the app can detect installed
> trail beacons and show information as you approach a landmark.
>
> The app has no accounts, advertising, analytics or tracking. Location and
> beacon detections are used on your device and are not sent to the developer.
>
> Warrington Talking Trails is provided by Warrington Township for visitors to
> Township parks and trails.

Keywords:

`Warrington,trails,parks,walking,tour,Lions Pride,Bradford Dam,accessibility,nature`

URLs:

- Support: `https://trails.warringtoneac.org/support.html`
- Privacy: `https://trails.warringtoneac.org/privacy.html`
- Marketing: optional; use `https://www.warringtoneac.org/` only with permission

## App privacy and compliance

- App Privacy: Data Not Collected, after confirming the release build contains
  no additional analytics or third-party SDKs.
- Tracking: No.
- Advertising identifier: No.
- Export compliance: the app uses only Apple-provided HTTPS networking and is
  marked as not using non-exempt encryption.
- Required-reason APIs: `UserDefaults`, declared as `CA92.1` in
  `PrivacyInfo.xcprivacy` for app-specific settings.
- Complete Apple's current age-rating questionnaire based on actual content;
  the expected result is suitable for all ages.
- Content rights: the release uses publisher-maintained content rather than
  externally licensed third-party content; answer No to third-party content.

## App Review notes

> Warrington Talking Trails can be fully reviewed without visiting the trails
> or detecting a physical beacon. Landmarks can be opened from Park Map search,
> and tours can be opened from the Trail Tours tab. Location is used to show the
> user's position and Bluetooth/iBeacon proximity is used to select a nearby
> landmark. Location and beacon observations are processed on-device and are
> not sent to the developer. The app has no login or purchases.

## Submission checklist

- Privacy and support pages deployed and verified on September 16, 2026.
- Open the existing Lions Pride Park app in App Store Connect and add version `2.0`.
- Confirm the build is signed by team `ZA7MADZY65` with the Lions Pride bundle ID.
- Run unit/UI tests and a Release archive on a healthy Xcode installation.
- Test a TestFlight build on physical hardware at both locations.
- Upload at least one current 6.9-inch iPhone screenshot without transparency.
- Complete App Privacy, age rating, content rights, pricing/availability, review contact, and release settings.
- Validate and upload the archive, attach the processed build, then submit it for review.

## Verified command-line TestFlight workflow

This is deliberately two-stage: the archive is unsigned, and Xcode applies
Apple's automatically managed App Store signing during export/upload.

From the repository root, replace `N` with the new build number after updating
both `CURRENT_PROJECT_VERSION` entries in
`WarringtonTalkingTrails.xcodeproj/project.pbxproj`:

```bash
xcodebuild archive \
  -project ios/WarringtonTalkingTrails.xcodeproj \
  -scheme WarringtonTalkingTrails \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/WarringtonTalkingTrails-N-unsigned.xcarchive \
  -derivedDataPath /tmp/warrington-talking-trails-archive-N \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -exportArchive \
  -archivePath /tmp/WarringtonTalkingTrails-N-unsigned.xcarchive \
  -exportPath /tmp/WarringtonTalkingTrails-N-export \
  -exportOptionsPlist ios/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath /tmp/WarringtonTalkingTrails-N-unsigned.xcarchive \
  -exportPath /tmp/WarringtonTalkingTrails-N-upload \
  -exportOptionsPlist ios/ExportOptions-AppStore-Upload.plist \
  -allowProvisioningUpdates
```

The middle command creates a signed IPA for inspection without uploading. The
last command uploads to App Store Connect. Check the archive and exported IPA's
`CFBundleVersion` before the upload.

Do not diagnose a missing local `Apple Distribution` identity as a lost or
expired certificate for this project. A normally signed command-line archive
selects development signing and may fail with “Your team has no devices.” That
is the wrong workflow here; use the unsigned archive plus automatic export
shown above. Xcode's `XcodeDistPipeline` temporary directories are also created
by this command-line export and do not imply that Organizer or the Xcode GUI was
used.
