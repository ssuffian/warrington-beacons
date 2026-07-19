//
//  ContentView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/1/20.
//  Copyright © 2020 Kevin Grainer. All rights reserved.
//

import SwiftUI

import CoreLocation

struct ContentView: View {
    // definitely use observableObject to hold the list of beaconds
    
    var body: some View {
        VStack {
            Button(action:{
                
            }) {
                Text("Start Bluetooth Scan")
            }
            Button(action:{
                
            }) {
                Text("Stop Bluetooth Scan")
            }
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
