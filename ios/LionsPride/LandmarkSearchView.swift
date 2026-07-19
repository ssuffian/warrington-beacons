//
//  TestSearchView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/24/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI
import CoreLocation

struct LandmarkSearchView: View {
    @Environment(UserData.self) var userData
    let array = landmarkService.getLandmarks()
    @State private var searchText = ""
    @State private var showCancelButton: Bool = false
    @Binding var showMap: Bool

    var body: some View {
            VStack {
                // Search view
                HStack {
                    HStack {
                        
                        Image(systemName: "magnifyingglass")

                        TextField("Search", text: $searchText, onEditingChanged: { isEditing in
                            self.showCancelButton = true
                            
                        }, onCommit: {
                            UIApplication.shared.endEditing(true)
                            })
                            .foregroundColor(.primary)
                            .autocapitalization(UITextAutocapitalizationType.none)
                        

                        Button(action: {
                            self.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill").opacity(searchText == "" ? 0 : 1)
                        }
                    }
                    .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
                    .foregroundColor(.secondary)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10.0)
                    
                }
                .padding(.horizontal)
                
                List {
                    // Filtered list of names
                    
                    if array.filter{$0.category == Landmark.Category.Trail && $0.name.uppercased().contains(searchText.uppercased()) || searchText == ""}.count > 0 {
                        Text("Trails").modifier(GrayUpperStyle())
                    }
                    LandmarkListRowView(landmarkArray: array, searchText: searchText, category: .Trail, showMap: $showMap).environment(userData)
                    if array.filter{$0.category == Landmark.Category.PointOfInterest && $0.name.uppercased().contains(searchText.uppercased()) || searchText == ""}.count > 0 {
                        Text("Points of Interest").modifier(GrayUpperStyle())
                    }
                    LandmarkListRowView(landmarkArray: array, searchText: searchText, category: .PointOfInterest, showMap: $showMap).environment(userData)
                    
                    if array.filter{$0.category == Landmark.Category.Building && $0.name.uppercased().contains(searchText.uppercased()) || searchText == ""}.count > 0 {
                        Text("Buildings").modifier(GrayUpperStyle())
                    }
                    LandmarkListRowView(landmarkArray: array, searchText: searchText, category: .Building, showMap: $showMap).environment(userData)
                }
                .resignKeyboardOnDragGesture()

        }.padding(.top)
    }
}

struct LandmarkListRowView: View {
    var landmarkArray: [Landmark]
    var searchText: String
    var category: Landmark.Category
    @Binding var showMap: Bool
    @Environment(UserData.self) var userData
    
    
    var body: some View{
        ForEach(landmarkArray.filter{$0.category == category && ($0.name.uppercased().contains(searchText.uppercased()) || searchText == "")}, id:\.self.id) { landmark in
                LandmarkRowView(landmark: landmark).onTapGesture {
                    self.showMap = true
                    self.userData.mainMapSelectedLandmark = landmark
                    UIApplication.shared.endEditing(true)
                }
        }
    }
}

struct TestSearchView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LandmarkSearchView(showMap: Binding.constant(false))
                .environment(UserData.shared)
        }
    }
}

extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(force)
    }
}

struct ResignKeyboardOnDragGesture: ViewModifier {
    var gesture = DragGesture().onChanged{_ in
        UIApplication.shared.endEditing(true)
    }
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

extension View {
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}


