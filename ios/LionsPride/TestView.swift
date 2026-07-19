//
//  TestView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/15/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

import SwiftUI

struct DetailView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var body: some View {
        Button(
            "Here is Detail View. Tap to go back.",
            action: { self.presentationMode.wrappedValue.dismiss() }
        )
    }
}

struct RootView: View {
    var body: some View {
        VStack {
            NavigationLink(destination: DetailView())
            { Text("I am Root. Tap for Detail View.") }
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            RootView()
        }.navigationBarTitle("Park Map", displayMode: .inline).navigationBarBackButtonHidden(true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        return ContentView()
    }
}
