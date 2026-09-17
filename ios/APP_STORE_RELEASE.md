# Warrington Talking Trails — App Store release

This is a **new app** for an independent Apple Developer account. It does not
update either existing Warrington Township App Store listing.

## App identity

- App Store name: `Warrington Talking Trails`
- Bundle ID: `org.warringtoneac.talkingtrails`
- SKU suggestion: `warrington-talking-trails-ios`
- Version: `1.0`
- Build: `2`
- Primary category: Travel
- Platform: iPhone
- Minimum OS: iOS 17.0

The bundle ID is a proposed unique identifier. Confirm it is available in the
developer account before creating the App Store Connect record. In Xcode,
select the app target, open Signing & Capabilities, select the personal team,
and leave Automatically manage signing enabled.

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
> This is an independent application for park visitors. It is not an official
> Warrington Township application.

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
- Add a new iOS app in App Store Connect with the bundle ID above.
- Select the developer's team in Xcode Signing & Capabilities.
- Run unit/UI tests and a Release archive on a healthy Xcode installation.
- Test a TestFlight build on physical hardware at both locations.
- Upload at least one current 6.9-inch iPhone screenshot without transparency.
- Complete App Privacy, age rating, content rights, pricing/availability, review contact, and release settings.
- Validate and upload the archive, attach the processed build, then submit it for review.
