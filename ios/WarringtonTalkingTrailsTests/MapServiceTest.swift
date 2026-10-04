//
//  MapServiceTest.swift
//  WarringtonTalkingTrailsTests
//
//  Created by Kevin Grainer on 5/12/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import XCTest
@testable import WarringtonTalkingTrails

class MapServiceTest: XCTestCase {

    // Data.json is a copy of server/api/v3/trails.json.
    var testLandmarkService: LandmarkService? = nil
    var decodedData: WarringtonTalkingTrailsData? = nil

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Data", withExtension: "json"))
        let decoded = try JSONDecoder().decode(WarringtonTalkingTrailsData.self, from: Data(contentsOf: url))
        let testService = LandmarkService()
        testService.processData(decoded)
        decodedData = decoded
        testLandmarkService = testService
    }

    override func tearDownWithError() throws {
        testLandmarkService = nil
        decodedData = nil
    }

    func testApiVersionThreeEndpoints() {
        XCTAssertEqual(API_MAJOR_VERSION, "v3")
        XCTAssertEqual(
            getApiUrlString(baseUrlString: "https://trails.warringtoneac.org/", resource: "trails.json"),
            "https://trails.warringtoneac.org/api/v3/trails.json"
        )
        XCTAssertEqual(
            getApiUrlString(baseUrlString: "https://trails.warringtoneac.org", resource: "talking-trails.kml"),
            "https://trails.warringtoneac.org/api/v3/talking-trails.kml"
        )
    }

    func testDecodesV3Snapshot() throws {
        let data = try XCTUnwrap(decodedData)
        let service = try XCTUnwrap(testLandmarkService)
        XCTAssertEqual(data.locations?.count, 2)
        XCTAssertFalse(data.landmarks.isEmpty)
        XCTAssertFalse(data.trails.isEmpty)

        let landmark = try XCTUnwrap(service.getLandmarkById(id: "EAC-2"))
        XCTAssertEqual(landmark.beaconMinor, 1)
        XCTAssertEqual(landmark.location, "us-202")

        // Every embedded stop references a decoded landmark by string ID.
        for trail in data.trails {
            for stopId in trail.stopIds {
                XCTAssertNotNil(service.getLandmarkById(id: stopId), "\(trail.id) stop \(stopId)")
            }
        }

        let lowerNike = try XCTUnwrap(service.getTrailById(id: "lower-nike-trail"))
        XCTAssertEqual(lowerNike.stopIds.first, "EAC-9")
        XCTAssertEqual(lowerNike.stopIds.last, "EAC-16")
    }

    func testTrailStartAndEndDecoding() throws {
        let service = try XCTUnwrap(testLandmarkService)

        let connector = try XCTUnwrap(service.getTrailById(id: "route-202-connector-trail"))
        XCTAssertTrue(connector.stopIds.isEmpty)
        XCTAssertNil(connector.end)
        let start = try XCTUnwrap(connector.start)
        XCTAssertEqual(start.latitude, 40.2700344, accuracy: 1e-9)
        XCTAssertEqual(start.longitude, -75.1917515, accuracy: 1e-9)
        XCTAssertFalse(start.directions.isEmpty)
        XCTAssertFalse(start.distance.isEmpty)
        // A route-only trail still gets a map center.
        XCTAssertNotNil(service.getTrailCenterCoordinates(id: connector.id))

        let lowerNike = try XCTUnwrap(service.getTrailById(id: "lower-nike-trail"))
        XCTAssertNil(lowerNike.start)
        let end = try XCTUnwrap(lowerNike.end)
        XCTAssertEqual(end.distance, "858 yards")
        XCTAssertEqual(end.directions, "858 yards to Waterfowl")

        let green = try XCTUnwrap(service.getTrailById(id: "green-trail"))
        XCTAssertNil(green.start)
        XCTAssertNil(green.end)
    }

    func testBeaconMinorMatching() throws {
        let service = try XCTUnwrap(testLandmarkService)
        XCTAssertEqual(service.getLandmarkByBeaconMinor(1)?.id, "EAC-2")
        XCTAssertEqual(service.getLandmarkByBeaconMinor(1002)?.id, "LP-2")
        XCTAssertNil(service.getLandmarkByBeaconMinor(65535))
    }

    func testPlaceWithoutBeaconMinorNeverMatches() throws {
        let json = #"""
        {
          "locations": [],
          "landmarks": [
            {"id": "X-1", "beaconMinor": 7, "imagePath": "x/images/a.jpg",
             "coordinates": {"latitude": 40.0, "longitude": -75.0}, "name": "Beacon place",
             "category": "PointOfInterest", "description": "d", "longDescription": "ld", "imageAlt": "a"},
            {"id": "X-2", "imagePath": "x/images/b.jpg",
             "coordinates": {"latitude": 40.001, "longitude": -75.001}, "name": "Quiet place",
             "category": "PointOfInterest", "description": "d", "longDescription": "ld", "imageAlt": "b"}
          ],
          "trails": [{
            "id": "t", "name": "T", "isOpen": true, "trailDistanceDescription": "",
            "boundaryCoordinates": [
              {"latitude": 40.0, "longitude": -75.0, "landmarkId": "X-1"},
              {"latitude": 40.001, "longitude": -75.001, "landmarkId": "X-2"}
            ]
          }]
        }
        """#.data(using: .utf8)!
        let service = LandmarkService()
        service.processData(try JSONDecoder().decode(WarringtonTalkingTrailsData.self, from: json))

        let quiet = try XCTUnwrap(service.getLandmarkById(id: "X-2"))
        XCTAssertNil(quiet.beaconMinor)
        XCTAssertEqual(service.getLandmarksByTrailId(id: "t").map(\.id), ["X-1", "X-2"])
        XCTAssertEqual(service.getLandmarkByBeaconMinor(7)?.id, "X-1")
        for minor in [0, 1, 2, 8, 65535] {
            XCTAssertNil(service.getLandmarkByBeaconMinor(minor), "minor \(minor)")
        }
        XCTAssertFalse(service.getLandmarks().contains { $0.id == "X-2" && $0.beaconMinor != nil })
    }

    func testPointsToNextLandmark() throws {
        let service = try XCTUnwrap(testLandmarkService)
        let trail = try XCTUnwrap(service.getTrailById(id: "lower-nike-trail"))
        let first = try XCTUnwrap(service.getLandmarkById(id: "EAC-9"))
        // EAC-9 is at index 34, EAC-10 at index 41.
        let forward = MapService.pointsToNextLandmark(trail: trail, currentLandmark: first, direction: .Clockwise)
        XCTAssertEqual(forward.count, 8)
    }

    func testFindNextLandmarkUsesStopOrder() throws {
        let service = try XCTUnwrap(testLandmarkService)
        let trail = try XCTUnwrap(service.getTrailById(id: "green-trail"))
        let first = try XCTUnwrap(service.getLandmarkById(id: "LP-3"))
        XCTAssertEqual(MapService.findNextLandmark(trail: trail, landmark: first, direction: .Clockwise, service: service)?.id, "LP-15")
        // Wraps around in reverse.
        XCTAssertEqual(MapService.findNextLandmark(trail: trail, landmark: first, direction: .CounterClockwise, service: service)?.id, "LP-16")
    }

    func testTourStepToTrailEnd() throws {
        let service = try XCTUnwrap(testLandmarkService)
        let trail = try XCTUnwrap(service.getTrailById(id: "lower-nike-trail"))
        let last = try XCTUnwrap(service.getLandmarkById(id: "EAC-16"))

        // Forward at the last stop: next target is the trail end, using the stop's own clockwise directions.
        let toEnd = MapService.tourStep(trail: trail, currentLandmark: last, direction: .Clockwise, service: service)
        XCTAssertEqual(toEnd.nextEndpoint, .end)
        XCTAssertEqual(toEnd.nextName, "Trail end")
        XCTAssertEqual(toEnd.directions, "858 yards to End of trail")

        // Standing at the end heading back: end directions lead to the last stop.
        let fromEnd = MapService.tourStep(trail: trail, currentLandmark: last, direction: .CounterClockwise, atEndpoint: .end, service: service)
        XCTAssertEqual(fromEnd.startingFromEndpoint, .end)
        XCTAssertEqual(fromEnd.nextLandmark?.id, "EAC-16")
        XCTAssertEqual(fromEnd.directions, "From the trail end: 858 yards to Waterfowl")

        // No start: reverse at the first stop keeps the existing behaviour.
        let first = try XCTUnwrap(service.getLandmarkById(id: "EAC-9"))
        let reverse = MapService.tourStep(trail: trail, currentLandmark: first, direction: .CounterClockwise, service: service)
        XCTAssertNil(reverse.nextEndpoint)
        XCTAssertEqual(reverse.nextLandmark?.id, "EAC-16")
    }

    func testTourStepFromTrailStart() throws {
        let json = #"""
        {
          "landmarks": [
            {"id": "S-1", "beaconMinor": 40, "imagePath": "x/images/a.jpg",
             "coordinates": {"latitude": 40.0, "longitude": -75.0}, "name": "One",
             "category": "PointOfInterest", "description": "d", "longDescription": "ld", "imageAlt": "a"}
          ],
          "trails": [{
            "id": "single", "name": "Single", "isOpen": true, "trailDistanceDescription": "",
            "start": {"latitude": 39.999, "longitude": -74.999, "distance": "100 feet", "directions": "100 feet to One"},
            "boundaryCoordinates": [
              {"latitude": 39.999, "longitude": -74.999},
              {"latitude": 40.0, "longitude": -75.0, "landmarkId": "S-1",
               "distanceToNextCounterClockwise": "100 feet", "distanceToNextCounterClockwiseDescription": "100 feet back to the start"}
            ]
          }]
        }
        """#.data(using: .utf8)!
        // MapService resolves stops through the shared landmarkService.
        landmarkService.processData(try JSONDecoder().decode(WarringtonTalkingTrailsData.self, from: json))
        let trail = try XCTUnwrap(landmarkService.getTrailById(id: "single"))
        let only = try XCTUnwrap(landmarkService.getLandmarkById(id: "S-1"))

        let fromStart = MapService.tourStep(trail: trail, currentLandmark: only, direction: .Clockwise, atEndpoint: .start)
        XCTAssertEqual(fromStart.startingFromEndpoint, .start)
        XCTAssertEqual(fromStart.nextLandmark?.id, "S-1")
        XCTAssertEqual(fromStart.directions, "From the trail start: 100 feet to One")

        let toStart = MapService.tourStep(trail: trail, currentLandmark: only, direction: .CounterClockwise)
        XCTAssertEqual(toStart.nextEndpoint, .start)
        XCTAssertEqual(toStart.directions, "100 feet back to the start")

        // A single-stop trail does not crash and wraps to itself.
        XCTAssertEqual(MapService.findNextLandmark(trail: trail, landmark: only, direction: .Clockwise)?.id, "S-1")
        XCTAssertEqual(MapService.getLandmarksOnTrail(trail: trail).map(\.id), ["S-1"])
    }

    func testCombinedAndroidDataFormat() throws {
        let json = #"""
        {
          "locations": [{
            "id": "us-202",
            "name": "US202 to Bradford Dam",
            "address": "Stump Road",
            "beaconMajorCode": 20,
            "iBeaconUUID": "035a0617-0875-4cc7-a29c-be0caa8f557c",
            "altBeaconUUID": "035a0617-0875-4cc7-a29c-be0caa8f557c"
          }],
          "landmarks": [{
            "id": "EAC-2",
            "beaconMinor": 1,
            "location": "us-202",
            "imagePath": "us-202/images/202Nesting.jpg",
            "coordinates": {"latitude": 40.0, "longitude": -75.0},
            "name": "Bluebird program",
            "category": "PointOfInterest",
            "description": "A landmark",
            "longDescription": "A landmark along the trail.",
            "imageAlt": "Bluebird sign"
          }],
          "trails": []
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WarringtonTalkingTrailsData.self, from: json)
        XCTAssertEqual(decoded.locations?.count, 1)
        XCTAssertNil(decoded.site)

        let service = LandmarkService()
        service.processData(decoded)
        let landmark = try XCTUnwrap(service.getLandmarkById(id: "EAC-2"))
        XCTAssertEqual(landmark.imageName, "202Nesting")
        XCTAssertEqual(
            landmark.imageUrl.absoluteString,
            "https://trails.warringtoneac.org/us-202/images/202Nesting.jpg"
        )
    }
}
