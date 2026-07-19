//
//  Map.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/3/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI
import MapKit

struct TrailTourMapView: UIViewRepresentable {
    var landmarks: [Landmark]
    @Environment(UserData.self) var userData
    @Binding var showPointOfInterestDetails: Bool
    @State var previousNearbyLandmark: Landmark?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = MKMapType.mutedStandard
        updateMapArea(map: mapView)
        return mapView
    }
    
    func updateMapArea(map:MKMapView) {
        if userData.trailLandmark != nil {
            let selectedLandmark = userData.trailLandmark!
            var span = landmarkService.getSpanForTrail(trailId: selectedLandmark.id)
            if span == nil {
                print("NO SPAN FOR \(selectedLandmark.name)")
                span = MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            }
            let region = MKCoordinateRegion(center: selectedLandmark.locationCoordinate, span: span!)
            map.setRegion(region, animated: true)
            let centerCoordinates = landmarkService.getCenterCoordinates(id: selectedLandmark.id)
            if centerCoordinates != nil {
                map.setCenter(centerCoordinates!, animated: false)
            }
            map.setCameraBoundary(
                MKMapView.CameraBoundary(coordinateRegion: region),
                animated: false)
        }
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        updateAnnotations(from: uiView)
        addBoundary(from: uiView)
        updateMapArea(map: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        final class Coordinator: NSObject, MKMapViewDelegate {
            var control: TrailTourMapView
            var landmarks: [Landmark]
            var trail: Trail

            init(_ control: TrailTourMapView) {
                self.control = control
                self.landmarks = control.landmarks
                let trailLandmark = self.landmarks.filter {l in
                    l.category == Landmark.Category.Trail
                }[0]
                self.trail = landmarkService.getTrailById(id: trailLandmark.id)!
            }
            
            func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                guard let annotation = annotation as? LandmarkAnnotation else { return nil }
                let identifier = "MainMapAnnotation\(annotation.id)"
                var annotationView: MKMarkerAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                // This block would update the map position to the latest beacon position when
                // the tour starts.  However, you just had the opportunity to pick a different
                // start position on the prior screen, and you might be walking away from the
                // last-seen beacon and toward your desired start position, so this is probably
                // undesirable.
                // e.g. Starting at Butterflies, you select Green Trailhead as your start
                // position for the tour, and start walking toward the Green Trailhead.
                // But your last seen beacon position is still Butterflies.  We don't want to
                // immediately override the tour to say you're at the end of the trail
                // (e.g. set your position to Butterflies when you had just picked Green Trailhead)
//                if control.userData.nearbyLandmark != nil && control.userData.nearbyLandmark != control.previousNearbyLandmark &&
//                    control.userData.nearbyLandmark != control.userData.trailTourCurrentLandmark &&
//                    MapService.isSelectedLandmarkOnTrail(trail: self.trail, landmark: control.userData.nearbyLandmark!) {
//
//                    control.previousNearbyLandmark = control.userData.nearbyLandmark
//                    control.userData.trailTourCurrentLandmark = control.userData.nearbyLandmark
//                    control.userData.trailTourNextLandmark = MapService.findNextLandmark(trail: control.userData.trailTourTrail!, landmark: control.userData.trailTourCurrentLandmark!, direction: control.userData.trailDirection)
//                    control.userData.checkForTrailTourEnd()
//                }
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.glyphImage = annotation.glyphImage
                    annotationView?.markerTintColor = annotation.glyphTintColor
                    annotationView?.displayPriority = .required
                    annotationView?.isEnabled = true
                } else {
                    annotationView?.annotation = annotation
                    annotationView?.glyphImage = annotation.glyphImage
                    annotationView?.markerTintColor = annotation.glyphTintColor
                    annotationView?.displayPriority = .required
                    annotationView?.isEnabled = true
                }
                return annotationView
            }
            
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                
                if overlay is MKPolygon {
                
                    if let polygon = overlay as? MKPolygon{
                        let polygonRenderer = MKPolygonRenderer(polygon: polygon)
                        polygonRenderer.strokeColor = TRAIL_SELECTED
                        polygonRenderer.lineWidth = LINE_WIDTH
                        polygonRenderer.lineDashPattern = [LINE_DASH_PATTERN, LINE_DASH_PATTERN]
                        return polygonRenderer
                    }
                }
                else if overlay is NamedPolyline {
                    if let polyline = overlay as? NamedPolyline {
                        if polyline.name == "Base" { // Base polyline is dashed line with no arrows
                            let polygonRenderer = MKPolylineRenderer(polyline: polyline)
                            polygonRenderer.strokeColor = TRAIL_SELECTED
                            polygonRenderer.lineWidth = LINE_WIDTH
                            polygonRenderer.lineDashPattern = [LINE_DASH_PATTERN, LINE_DASH_PATTERN]
                            return polygonRenderer
                        }
                        else { // Directions polyline is solid line with arrows, drawn on top of Base one
                            // Arrow renderer always uses direction "Clockwise" here because the underlying points
                            // are already straight or reversed depending on the current trail navigation direction
                            // so the arrows should always point from beginning of polyline to end or whatever
                            let polylineRenderer = ArrowPolylineRenderer(overlay: polyline, direction: .Clockwise)
                            polylineRenderer.strokeColor = TRAIL_SELECTED
                            polylineRenderer.lineWidth = LINE_WIDTH
                            return polylineRenderer
                        }
                    }
                }
                return MKOverlayRenderer(overlay: overlay)
            }
            
            func mapView(_ mapView: MKMapView,
                         didSelect view: MKAnnotationView) {
                
                let annotation = view.annotation as? LandmarkAnnotation
                if annotation != nil && annotation?.landmark != nil {
                    let landmark = landmarkService.getLandmarkById(id: annotation!.landmark!.id)
                
                    if landmark != nil {
                        control.userData.trailTourSelectedLandmark = landmark!
                        control.showPointOfInterestDetails = true
                    }
                }
            }
        }
    
    
    private func updateAnnotations(from mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations)
        let newAnnotations = landmarks.map { LandmarkAnnotation(landmark: $0) }
        mapView.addAnnotations(newAnnotations)
    }
    
    private func addBoundary(from mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        
        let trailLandmark = self.landmarks.filter {l in
            l.category == Landmark.Category.Trail
        }
        
        if trailLandmark.count > 0 {
            // what to do if no landmarks are a trail?
            let trail = landmarkService.getTrailById(id: trailLandmark[0].id)
            if trail != nil {
                var points = trail!.boundaryCoordinates.map{CLLocationCoordinate2D(
                                    latitude: $0.latitude,
                                    longitude: $0.longitude)}
//                print(trail!.isOpen)
//                if !trail!.isOpen {
//                    points.append(CLLocationCoordinate2D(latitude: points[0].latitude, longitude: points[0].longitude))
//                }
                let polygon = NamedPolyline(coordinates:points, count: points.count)
                polygon.name = "Base"
                mapView.addOverlay(polygon)
//                if !self.userData.trailTourEnded {
//                    let lineCoordinates = MapService.pointsToNextLandmark(trail: trail!, currentLandmark: self.userData.trailTourCurrentLandmark!, direction: self.userData.trailDirection)
//                    let polyline = NamedPolyline(coordinates:
//                        lineCoordinates, count: lineCoordinates.count)
//                    polyline.name = "Directions"
//                    mapView.insertOverlay(polyline, above: polygon)
//                }
            }
        }
    }
}

struct TrailTourMapView_Previews: PreviewProvider {
    static var previews: some View {
        TrailTourMapView(landmarks: landmarkService.getLandmarks(), showPointOfInterestDetails: Binding.constant(false)).environment(UserData.shared)
    }
}

