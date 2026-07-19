//
//  MapServiceTest.swift
//  LionsPrideTests
//
//  Created by Kevin Grainer on 5/12/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import XCTest
@testable import _02Connector

class MapServiceTest: XCTestCase {
    
    var testLandmarkService: LandmarkService? = nil
    
    override func setUpWithError() throws {
        let landmarkData = try Data(contentsOf: Bundle(for: Self.self).url(forResource: "Data", withExtension: "json")!) // Force-unwrapping is safe because this file is well-known to exist in the test bundle
        print(String(decoding: landmarkData, as: UTF8.self))
        let testService = LandmarkService()
        testService.processData(try JSONDecoder().decode(LionsPrideData.self, from: landmarkData))
        testLandmarkService = testService
    }

    override func tearDownWithError() throws {
        testLandmarkService = nil
    }

    func testClockwiseBlueTrail() throws {
        let concreteTestLandmarkService = try XCTUnwrap(testLandmarkService, "A suitable test landmark service couldn't be created")
        
        let blueTrailLM = concreteTestLandmarkService.getLandmarkById(id: 1001)
        let blueTrail = concreteTestLandmarkService.getTrailById(id: 1001)
        let coordinates = MapService.pointsToNextLandmark(trail: blueTrail!, currentLandmark: blueTrailLM!, direction: Direction.Clockwise)
        print(coordinates)
        print(coordinates.count)
        XCTAssertEqual(coordinates.count, 2, "The map service found the wrong number of coordinates")
        
        /*
         "boundaryCoordinates": [{
                 "latitude": 40.2454,
                 "longitude": -75.1786,
                 "landmarkId": 1001
             },
             {
                 "longitude": -75.1783427,
                 "latitude": 40.2458652,
                 "landmarkId": 1009
             },
             {
                 "longitude": -75.1781982,
                 "latitude": 40.2461667,
                 "landmarkId": 1012
             },
             {
                 "latitude": 40.2462,
                 "longitude": -75.1781
             },
             {
                 "latitude": 40.2467,
                 "longitude": -75.1784
             },
             {
                 "latitude": 40.2462,
                 "longitude": -75.1787
             },
             {
                 "longitude": -75.1788337,
                 "latitude": 40.246209,
                 "landmarkId": 1016
             }
         ],
         */
        
        
    }
    
    func testCounterClockwiseBlueTrail() throws {
        let concreteTestLandmarkService = try XCTUnwrap(testLandmarkService, "A suitable test landmark service couldn't be created")
        
        let blueTrailLM = concreteTestLandmarkService.getLandmarkById(id: 1001)
        let blueTrail = concreteTestLandmarkService.getTrailById(id: 1001)
        let coordinates = MapService.pointsToNextLandmark(trail: blueTrail!, currentLandmark: blueTrailLM!, direction: Direction.CounterClockwise)
        print(coordinates)
        print(coordinates.count)
        XCTAssertEqual(coordinates.count, 2, "The map service found the wrong number of coordinates")
    }
}
