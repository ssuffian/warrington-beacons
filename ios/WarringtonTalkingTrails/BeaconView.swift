//
//  BeaconView.swift
//  Lions Pride
//
//  Created by Don Coleman on 8/4/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct BeaconInfoView: View {
    var beacon: RangedBeacon
    var landmark: Landmark?

    init(beacon: RangedBeacon) {
        self.beacon = beacon
        self.landmark = landmarkService.getLandmarkById(id: beacon.minor)
    }
    var body: some View {
        HStack {
            Text("\(self.beacon.minor)")
            if (self.landmark != nil) {
                Text("\(self.landmark!.name)").frame(width: 125, alignment: .leading)
            } else {
                Text("???").frame(width: 125, alignment: .leading)
            }
            Text(self.beacon.proximityDescription).frame(width: 90, alignment: .leading)
            Text(String(format: "%.2f", self.beacon.accuracy) + "m").frame(alignment: .trailing)

        }
    }
}

// This View is only for development and should NOT be included in the production release
struct BeaconListView: View {
    @EnvironmentObject var scanner: BeaconScanner
    var body: some View {
        NavigationStack {
            List {
                ForEach(self.scanner.beacons) { beacon in
                    BeaconInfoView(beacon: beacon)
                }
            }.navigationBarTitle("Beacons")
        }
    }
}

struct BeaconListView_Previews: PreviewProvider {

    static var previews: some View {
        return BeaconListView().environmentObject(BeaconScanner.shared)
    }
}
