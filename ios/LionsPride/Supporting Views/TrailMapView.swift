//
//  Map.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/3/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI
import MapKit

struct TrailMapView: UIViewRepresentable {
    var trailLandmark: Landmark
    @Environment(UserData.self) var userData

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = MKMapType.mutedStandard
        var span = landmarkService.getSpanForTrail(trailId: trailLandmark.id)
        if span == nil {
            print("NO SPAN FOR \(trailLandmark.name)")
            span = MKCoordinateSpan(latitudeDelta: 0.0031, longitudeDelta: 0.0031)
        }
        let region = MKCoordinateRegion(center: trailLandmark.locationCoordinate, span: span!)
        mapView.setRegion(region, animated: true)
        let centerCoordinates = landmarkService.getCenterCoordinates(id: trailLandmark.id)
        if centerCoordinates != nil {
            mapView.setCenter(centerCoordinates!, animated: true)
        }
        mapView.setCameraBoundary(
            MKMapView.CameraBoundary(coordinateRegion: region),
            animated: true)
        
        updateAnnotations(from: mapView)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        addBoundary(from: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        final class Coordinator: NSObject, MKMapViewDelegate {
            var control: TrailMapView
            var trailLandmark: Landmark

            init(_ control: TrailMapView) {
                self.control = control
                self.trailLandmark = control.trailLandmark
            }
            
            func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                guard let annotation = annotation as? LandmarkAnnotation else { return nil }
                let identifier = "MapAnnotation\(annotation.id)"
                var annotationView: MKMarkerAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.glyphImage = annotation.glyphImage
                    annotationView?.markerTintColor = annotation.glyphTintColor
                    annotationView?.displayPriority = .required
                    annotationView?.isEnabled = true
                    // leaves it selected and if we want to have this default selected then on didSelect we need to unselect it if it's not selected.  I think that will cause some issues with re-rendering, not positive
//                    if Int(annotation.id) == self.trailLandmark.id {
//                        annotationView?.setSelected(true, animated: true)
//                    }
                } else {
                    annotationView?.annotation = annotation
                    annotationView?.glyphImage = annotation.glyphImage
                    annotationView?.markerTintColor = annotation.glyphTintColor
                    annotationView?.displayPriority = .required
                    annotationView?.isEnabled = true
                }
                return annotationView
            }
            
            func mapView(_ mapView: MKMapView,
                         didSelect view: MKAnnotationView) {
                
                let annotation = view.annotation as? LandmarkAnnotation
                
                let landmark = landmarkService.getLandmarkById(id: annotation!.landmark!.id)
                
                if landmark != nil {
                    self.control.userData.trailTourCurrentLandmark = landmark!
                    self.control.userData.checkForTrailTourEnd()
                }
            }
            
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                
                if overlay is MKPolygon {
                    if let polygon = overlay as? MKPolygon{
                        let polygonRenderer = ArrowPolygonRenderer(overlay: polygon, direction: self.control.userData.trailDirection)
                        polygonRenderer.strokeColor = TRAIL_SELECTED
                        polygonRenderer.lineWidth = 2
                        polygonRenderer.lineDashPattern = [LINE_DASH_PATTERN, LINE_DASH_PATTERN]
                        return polygonRenderer
                    }
                }
                else if overlay is MKPolyline {
                    if let polyline = overlay as? MKPolyline{
                        let polygonRenderer = ArrowPolylineRenderer(overlay: polyline, direction: self.control.userData.trailDirection)
                        polygonRenderer.strokeColor = TRAIL_SELECTED
                        polygonRenderer.lineWidth = 2
                        polygonRenderer.lineDashPattern = [LINE_DASH_PATTERN, LINE_DASH_PATTERN]
                        return polygonRenderer
                    }
                }
                return MKOverlayRenderer(overlay: overlay)
            }
        }
    
    private func updateAnnotations(from mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations)
        
        var newAnnotations = [LandmarkAnnotation]()
        
        newAnnotations.append(contentsOf: landmarkService.getLandmarksByTrailId(id: trailLandmark.id).map
            {
                LandmarkAnnotation(landmark: $0)
            })
        mapView.addAnnotations(newAnnotations)
    }
    
    private func addBoundary(from mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        let trail = landmarkService.getTrailById(id: trailLandmark.id)
        if trail != nil {
            var points = trail!.boundaryCoordinates.map{CLLocationCoordinate2D(
                                latitude: $0.latitude,
                                longitude: $0.longitude)}
            if !trail!.isOpen {
                points.append(CLLocationCoordinate2D(latitude: points[0].latitude, longitude: points[0].longitude))
            }
            let polygon = MKPolyline(coordinates:points, count: points.count)
            mapView.addOverlay(polygon)
        }
    }
}

struct TrailMapView_Previews: PreviewProvider {
    
    static var previews: some View {

        TrailMapView(trailLandmark: landmarkService.getLandmarkById(id: 1002)!).environment(UserData.shared)
    }
}

