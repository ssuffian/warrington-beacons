//
//  MainView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/2/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import CoreLocation
import SwiftUI



struct MainView: View {
    
    @Environment(UserData.self) var userData
    @State private var selection = 0
    @State private var aboutDismissed = false
    @State private var showSplash = true
    @State private var showWelcome = false
    @State private var showMap = true
    @State private var searchText = ""
    @State private var showCancelButton = false
    @State private var showPointOfInterestDetails = false
    @State private var showPointOfInterestSummary = false
    @State private var locationPermissionDenied = false
    
    var body: some View {
        
            ZStack{
                if !showSplash && !showWelcome {
                    TabView(selection: $selection){
                        NavigationStack {
                        ZStack {
                            MainMapContainerView(showMap: $showMap).environment(userData).padding(.top)
                            if self.userData.mainMapSelectedLandmark != nil && showMap {
                                VStack {
                                    Spacer()
                                
                                    PointOfInterestSummaryView(showDetails: self.showPointOfInterestDetails, showPointOfInterestSummary: self.$showPointOfInterestSummary, showPointOfInterestDetails: self.$showPointOfInterestDetails, selectedTab: self.$selection).environment(self.userData).background(Color(.secondarySystemBackground)).frame(height: self.userData.screenSize.height > 700 ? 150: 120)
                                }
                            }

                        }.navigationBarTitle("Park Map", displayMode: .inline)
                            .sheet(isPresented: self.$showPointOfInterestDetails) {
                                PointOfInterestDetailsView(landmark: self.userData.mainMapSelectedLandmark!, close:{
                                        self.showPointOfInterestDetails = false
                                }).background(Color(.secondarySystemBackground)).environment(self.userData)
                            }

                        }.statusBar(hidden: true)
                        .tabItem {
                            VStack {
                                Image(systemName: "map").onTapGesture {
                                    self.showMap = true
                                }
                                Text("Park Map").modifier(TabLabelStyle())
                            }
                        }
                        .tag(0)
                        .onAppear {
                            print("Main map showing \(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)")
                            self.userData.parkMapVisible = true
                            BeaconScanner.shared.startScanning()
                            self.userData.resetLandmarkDistance()
                        }.onDisappear {
                            print("Main map hiding")
                            self.userData.parkMapVisible = false
                            BeaconScanner.shared.stopScanning()
                            // Important to suppress user location updates
                            self.userData.mainMapSelectedLandmark = nil
                        }
    
                        TrailListView().environment(self.userData)
                            .tabItem {
                                VStack {
                                    Image(systemName: "mappin.and.ellipse")
                                }
                                Text("Trail Tours").modifier(TabLabelStyle())
                            }
                            .tag(1)
                            .onAppear {
                                print("Trail List/Detail/Tour tab showing")
                            }.onDisappear {
                                print("Trail List/Detail/Tour tab hiding")
                                self.userData.forceStartTour = false
                            }
                        
                        AboutView()
                            .tabItem {
                                VStack {
                                    Image(systemName: "info.circle")
                                }
                                Text("About").modifier(TabLabelStyle())
                            }
                            .tag(2)
                        
                        SettingsView().environment(self.userData)
                            .tabItem {
                                VStack {
                                    Image(systemName: "gear")
                                }
                                Text("Settings").modifier(TabLabelStyle())
                            }
                            .tag(3)
                        
                        // Beacons tab, only for debugging
                        // TODO comment out for production
                        #if DEBUG
                        BeaconListView().environmentObject(BeaconScanner.shared)
                                .tabItem {
                                    VStack {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                    }
                                    Text("Beacons").modifier(TabLabelStyle())
                                }
                                .tag(4)
                                .onAppear { BeaconScanner.shared.startScanning() }
                                .onDisappear { BeaconScanner.shared.stopScanning() }
                        #endif
                    }.onAppear {
                        DispatchQueue.main.async {
                            self.loadData()
                            self.locationPermissionDenied = BeaconScanner.shared.locationPermissionDenied
                        }
                    }
                }
                
                if showWelcome {
                    WelcomeView(showWelcome: self.$showWelcome)
                }
                
                if showSplash {
                    SplashScreenView()
                        .onAppear {
                          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut) {
                                self.showSplash = false
                                // Only show the welcome screen on first launch
                                self.showWelcome = !UserDefaults.standard.bool(forKey: "welcome_seen")
                            }
                          }
                        }.edgesIgnoringSafeArea(.all)
                }
            }.alert(isPresented: $locationPermissionDenied) {
                Alert(title: Text("Location permission denied"),
                message: Text("This app uses location to show your position on map and scan for beacons in the park. For the best experience please enable location in your phone settings."),
                primaryButton: .default(Text("Go To Settings")){
                  UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                 },
                secondaryButton: .default(Text("Dismiss")))
            }
    }
        
    func showPointOfInterest() -> Bool {
        return selection == 0 && self.userData.mainMapSelectedLandmark != nil && showMap &&
        !showWelcome && !showSplash
    }
        
    func loadData() {
        guard let url = URL(string: "\(BASE_URL_STRING)/us202trail-v2.json") else {
            print("Invalid URL")
            return
        }

        // Revalidate with the server when online (a cheap ETag 304 unless the file
        // changed) so content updates are noticed promptly; if the network is
        // unreachable (poor signal on the trail), fall back to the last cached copy.
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadRevalidatingCacheData
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, self.decodeAndApply(data) {
                return
            }
            print("Error loading trail data (\(error?.localizedDescription ?? "unknown error")), trying cache")
            var cachedRequest = URLRequest(url: url)
            cachedRequest.cachePolicy = .returnCacheDataDontLoad
            URLSession.shared.dataTask(with: cachedRequest) { data, _, cacheError in
                if let data = data, self.decodeAndApply(data) {
                    return
                }
                print("No cached trail data available: \(cacheError?.localizedDescription ?? "unknown error")")
            }.resume()
        }.resume()
    }

    private func decodeAndApply(_ data: Data) -> Bool {
        do {
            let decodedResponse = try JSONDecoder().decode(LionsPrideData.self, from: data)
            landmarkService.processData(decodedResponse)
            DispatchQueue.main.async {
                self.userData.initialized = true
            }
            return true
        } catch {
            print(error)
            return false
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let userData = UserData.shared
        return MainView().environment(userData)
    }
}
