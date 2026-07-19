//  BeaconScanner
//
//  Created by Kevin Grainer on 4/16/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import CoreLocation

// Plain value type between CoreLocation and the rest of the app, so beacon
// handling can be exercised without real radio (see FakeBeacon below).
struct RangedBeacon: Identifiable {
    let minor: Int
    let accuracy: Double          // estimated meters; < 0 means unknown/very far
    let proximityDescription: String
    let timestamp: Date

    var id: Int { minor }

    init(minor: Int, accuracy: Double, proximityDescription: String, timestamp: Date = Date()) {
        self.minor = minor
        self.accuracy = accuracy
        self.proximityDescription = proximityDescription
        self.timestamp = timestamp
    }

    init(from beacon: CLBeacon) {
        let proximity: String
        switch beacon.proximity {
        case .unknown: proximity = "Unknown"
        case .far: proximity = "Far"
        case .near: proximity = "Near"
        case .immediate: proximity = "Immediate"
        @unknown default: proximity = "UNKNOWN"
        }
        self.init(minor: beacon.minor.intValue,
                  accuracy: beacon.accuracy,
                  proximityDescription: proximity,
                  timestamp: beacon.timestamp)
    }

    var hasKnownProximity: Bool { proximityDescription != "Unknown" }
}

class BeaconScanner: NSObject, CLLocationManagerDelegate, ObservableObject {

    @Published var beacons: [RangedBeacon] = []   // publish for the debug view
    var locationPermissionDenied = false      // mainview checks on startup

    // All beacons in a park have the same UUID and major value
    // TODO get this from the site section of the JSON file
    let UUID_STRING = "035a0617-0875-4cc7-a29c-be0caa8f557c"
    let MAJOR_VALUE = CLBeaconMajorValue(20)

    private let constraint: CLBeaconIdentityConstraint

    private var lastNearbyBeaconId: Int?

    // While simulated beacons are active (debug builds), real scan results are
    // ignored so they can't overwrite the fakes.
    private var simulationActive = false

    // must see a beacon at least this many times before notifying
    private let MIN_SEEN_COUNT = 3
    // number of times a beacon has been seen since the last notification was sent
    private var beaconSeenCount: [Int: Int] = [:]

    // wait at least this long before notifing the user of a beacon again
    private let MIN_NOTIFICATION_SECONDS: Double = 60
    // last time a notification was sent for a beacon
    private var lastNotificationCache: [Int: Date] = [:]

    var locationManager: CLLocationManager = CLLocationManager();
    var authorizationStatus: CLAuthorizationStatus = CLAuthorizationStatus.notDetermined

    static let shared = BeaconScanner()

    private override init () {
        let uuid = UUID(uuidString: UUID_STRING)!
        self.constraint = CLBeaconIdentityConstraint(uuid: uuid, major: MAJOR_VALUE)
        super.init()

        locationManager.delegate = self
    }

    func startScanning() {
        print("\(type(of:self)): \(#function)")
        logAuthorizationStatus()

        lastNearbyBeaconId = nil
        // possibly reset lastNotificationCache and/or beaconSeenCount too, need to test

        if CLLocationManager.isRangingAvailable() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startRangingBeacons(satisfying: constraint)
            locationManager.startUpdatingLocation()
        } else {
            print("Beacon ranging is not available on this device")
        }
    }

    func stopScanning() {
        print("\(type(of:self)): \(#function)")
        locationManager.stopUpdatingLocation()
        locationManager.stopRangingBeacons(satisfying: constraint)
    }

    private func getClosestBeacon(beacons: [RangedBeacon]) -> RangedBeacon? {
        // remove beacons with unknown proximity
        let filteredBeacons = beacons.filter({ $0.hasKnownProximity })
        // sort by distance (accuracy), with anything below zero at the end (really far ones show accuracy of -1)
        let sortedBeacons = filteredBeacons.sorted(by: {($0.accuracy < 0 ? 999 : $0.accuracy) < ($1.accuracy < 0 ? 999 : $1.accuracy)})

        return sortedBeacons.first
    }

    private func process(_ beacon: RangedBeacon) {

        let beaconId = beacon.minor

        // increase the seen count
        if let count = beaconSeenCount[beaconId] {
            beaconSeenCount[beaconId] = count + 1
        } else {
            beaconSeenCount[beaconId] = 1
        }

        // get it again with the new count
        if let count = beaconSeenCount[beaconId] {

            if count >= MIN_SEEN_COUNT && notLastNearbyBeacon(beacon) {

                if enoughTimeSinceLastNotification(beacon: beacon) {
                    print("\(beaconId) is new")
                    lastNearbyBeaconId = beaconId
                    UserData.shared.updateLocation(minor: beaconId)  // update UI (should be using protcol)
                    beaconSeenCount.removeAll()  // reset the count
                }

            }
        }

    }

    private func notLastNearbyBeacon(_ beacon: RangedBeacon) -> Bool {
        lastNearbyBeaconId != beacon.minor
    }

    private func enoughTimeSinceLastNotification(beacon: RangedBeacon) -> Bool {

        let beaconId = beacon.minor

        if let lastNotification: Date = lastNotificationCache[beaconId] {
            if (beacon.timestamp.timeIntervalSince(lastNotification) < MIN_NOTIFICATION_SECONDS) {
                return false
            }
        }

        lastNotificationCache[beaconId] = beacon.timestamp
        return true
    }

    private func logAuthorizationStatus() {

        switch(authorizationStatus) {
        case .authorizedWhenInUse:
             print("Location permissions are authorizedWhenInUse")
        case .notDetermined:
            print("Location permissions have not been determined yet")
        case .denied:
            print("Location permissions are denied")
        case .restricted:
            print("Location permissions are restricted")
        default:
            print("Unexpected CLAuthorizationStatus \(authorizationStatus.rawValue)")
        }

    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        logAuthorizationStatus()
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {

        if simulationActive { return }

        let ranged = beacons.map { RangedBeacon(from: $0) }

        if let beacon = getClosestBeacon(beacons: ranged) {
            print("Closest: \(beacon.minor) \(beacon.proximityDescription) \(String(format:"%.2f", beacon.accuracy))")

            // An accuracy of under 30m triggers (was proximity near/immediate)
            if beacon.accuracy > 0 && beacon.accuracy < 30 {
                process(beacon)
            }
        } else {
            lastNearbyBeaconId = nil
        }

        #if DEBUG
        // copy into published var for debug view
        self.beacons = ranged.sorted(by: {($0.accuracy < 0 ? 999 : $0.accuracy) < ($1.accuracy < 0 ? 999 : $1.accuracy)})
        #endif

    }

    func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Error) {

        logAuthorizationStatus()

        if authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse {
            // The user granted location permission, Bluetooth is probably disabled
            print("Ranging failed. The user has granted location permission, so Bluetooth is probably disabled.")

            // Start the Bluetooth service so the user is prompted to enable Bluetooth
            let _ = BluetoothService.shared

        } else {
            // The user DID NOT grant location permission, the app will not be very usable
            print("Ranging failed because the user did NOT grant location permission.")
            // The app will show an Alert on startup
        }

    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        UserData.shared.updateCurrentLocation(location: location)
    }

}

#if DEBUG
// MARK: - Fake beacons (debug builds only)
//
// The simulator cannot range real iBeacons, so debug builds register the
// `bradfordtrail://` URL scheme (declared in Info.plist, handled by
// BradfordTrailApp's .onOpenURL) and fake detections can be driven from the
// command line — or just use the ./simulate_beacon.sh wrapper at the repo root:
//
//   xcrun simctl openurl booted "bradfordtrail://fakebeacon?minor=7&distance=2.5"
//   xcrun simctl openurl booted "bradfordtrail://fakebeacon/clear"
//
// Injection bypasses the seen-count/cooldown debouncing on purpose (dev loops
// shouldn't wait 60s); the debounce logic still governs real radio.
extension BeaconScanner {

    func injectSimulatedBeacon(minor: Int, accuracy: Double) {
        print("FakeBeacon: injecting minor=\(minor) accuracy=\(accuracy)")
        simulationActive = true
        beacons = [RangedBeacon(minor: minor, accuracy: accuracy, proximityDescription: "Simulated")]
        UserData.shared.updateLocation(minor: minor)
    }

    func clearSimulatedBeacons() {
        print("FakeBeacon: clearing")
        simulationActive = false
        beacons = []
        lastNearbyBeaconId = nil
    }
}

enum FakeBeacon {
    static func handle(url: URL) {
        guard url.scheme == "bradfordtrail", url.host == "fakebeacon" else { return }
        if url.path == "/clear" {
            BeaconScanner.shared.clearSimulatedBeacons()
            return
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let minorString = components?.queryItems?.first(where: { $0.name == "minor" })?.value,
              let minor = Int(minorString) else {
            print("FakeBeacon: no valid 'minor' query item in \(url)")
            return
        }
        let distance = components?.queryItems?.first(where: { $0.name == "distance" })?.value
            .flatMap(Double.init) ?? 1.0
        BeaconScanner.shared.injectSimulatedBeacon(minor: minor, accuracy: distance)
    }
}
#endif
