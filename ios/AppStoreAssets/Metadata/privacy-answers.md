# App Privacy answers

Use these answers for the App Privacy questionnaire after confirming no new SDK
or data collection was added after build `2.0 (20260923.1)`.

- Does this app collect data? **No, we do not collect data from this app.**
- Tracking: **No**
- Data used to track you: **None**
- Data linked to you: **None**
- Data not linked to you: **None**
- Advertising identifier: **Not used**
- Privacy Policy URL: `https://trails.warringtoneac.org/privacy.html`

The app accesses location locally to display the user's map position and detect
nearby beacons. That location is not transmitted to or received by the
developer, so it is not collected under Apple's App Privacy definition. The
privacy manifest in the submitted build declares no collected data, no
tracking, and the `UserDefaults` required-reason API under reason `CA92.1`.
