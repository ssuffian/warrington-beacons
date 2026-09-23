# Physical-device App Review recording

Apple requested a recording made on a physical iPhone running the latest iOS.
Use the latest TestFlight version of Warrington Talking Trails: `2.0 (20260923.1)`.

## Prepare the iPhone

1. Update the iPhone to the latest available iOS release.
2. Install build `2.0 (20260923.1)` from TestFlight and launch it once to confirm it loads.
3. Turn on Focus or Do Not Disturb so private notifications do not appear.
4. Confirm Screen Recording is in Control Center. If it is missing, open Control
   Center, enter edit mode, choose **Add a Control**, and add **Screen Recording**.
   On older iOS versions, add it from **Settings > Control Center**.
5. If you will narrate the video, touch and hold the Screen Recording control and
   turn **Microphone** on. Narration is optional, but it can help explain that
   physical beacon detection only works at the supported trails.

## Capture the recording

1. Start from the iPhone Home Screen.
2. Open Control Center and tap **Screen Recording**. Wait for the three-second countdown.
3. Close Control Center, remain on the Home Screen, and then launch Warrington Talking Trails.
4. Show this typical flow:
   - Complete the welcome screen and permission prompts if they appear.
   - Show the Park Map and open a landmark.
   - Open Search and select a different landmark.
   - Open **Trail Tours** and choose a trail.
   - Select Forward or Reverse, then tap **Start Tour**.
   - Open the next landmark's details and demonstrate **Reverse**.
   - Open Settings and demonstrate **Simplified Text**.
5. Demonstrate VoiceOver:
   - Ask Siri to “Turn on VoiceOver,” or enable it in
     **Settings > Accessibility > VoiceOver**.
   - With VoiceOver active, tap once to focus an item and double-tap to activate it.
   - Navigate the tabs, a trail row, direction buttons, Start Tour, and a landmark.
   - If recording at a supported trail, approach a working beacon and capture the
     automatic spoken landmark announcement.
6. Stop the recording by tapping the red recording indicator and choosing **Stop**,
   or open Control Center and tap Screen Recording again.
7. Open the recording in Photos and play it all the way through. Confirm the app
   launch is visible, text is readable, and VoiceOver speech is audible.

## Submit it to Apple

1. Attach the video to the App Review conversation in App Store Connect.
2. Replace `[RECORDING FILENAME]`, `[IPHONE MODEL]`, and `[IOS VERSION]` in
   `review-notes.txt`.
3. Paste the complete contents of `review-notes.txt` into both:
   - the reply to App Review; and
   - the **Notes** field under **App Review Information**.
4. Confirm the version submission uses build `2.0 (20260923.1)` before replying.
