//
//  Map.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/3/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI
import MapKit


final class LandmarkAnnotation: NSObject, MKAnnotation {
    let id: String
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let subtitle: String?
    let landmark: Landmark?

    init(landmark: Landmark) {
        self.id = String(landmark.id)
        self.title = landmark.trailModifiedName
        self.coordinate = landmark.locationCoordinate
        self.subtitle = ""
        self.landmark = landmark
    }
    
    var glyphImage: UIImage? {
        if landmark?.category.rawValue == "Trail" {
            return UIImage(systemName: "arrow.clockwise.circle.fill")
        } else if landmark?.category.rawValue == "PointOfInterest"{
            return UIImage(systemName: "photo.fill")
        } else if landmark?.category.rawValue == "Building" {
            return UIImage(systemName: "house.fill")
        }
        return UIImage(systemName: "gear")
    }
    
    var glyphTintColor: UIColor? {
        if landmark?.category.rawValue == "Trail" {
            return GREEN
        } else if landmark?.category.rawValue == "PointOfInterest"{
            return ORANGE
        } else if landmark?.category.rawValue == "Building" {
            return YELLOW
        }
        return GREEN
    }
    
}

struct MainMapView: UIViewRepresentable {
    let LATITUDE_DELTA = 0.04
    let LONGITUDE_DELTA = 0.04
    
    var coordinate: CLLocationCoordinate2D
    var landmarks: [Landmark]
    @Environment(UserData.self) var userData

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = MKMapType.mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        let span = MKCoordinateSpan(latitudeDelta: LATITUDE_DELTA, longitudeDelta: LONGITUDE_DELTA)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: false)
        mapView.setCameraBoundary(
            MKMapView.CameraBoundary(coordinateRegion: region),
            animated: false)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        
        updateAnnotations(from: uiView)
        addBoundary(from: uiView)
        
    }
    
    
    func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        final class Coordinator: NSObject, MKMapViewDelegate {
            var control: MainMapView

            init(_ control: MainMapView) {
                self.control = control
            }
            
            
            func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                guard let annotation = annotation as? LandmarkAnnotation else { return nil }
                let identifier = "MainMapAnnotation\(annotation.id)"
                var annotationView: MKMarkerAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.glyphImage = annotation.glyphImage
                    annotationView?.markerTintColor = annotation.glyphTintColor
                    annotationView?.displayPriority = .required
                    if control.userData.mainMapSelectedLandmark != nil && annotation.landmark == control.userData.mainMapSelectedLandmark {
                        annotationView?.setSelected(true, animated: true)
                    }
                } else {
                    annotationView?.annotation = annotation
                    annotationView?.glyphImage = annotation.glyphImage
                    annotationView?.markerTintColor = annotation.glyphTintColor
                    if control.userData.mainMapSelectedLandmark != nil && annotation.landmark == control.userData.mainMapSelectedLandmark {
                        annotationView?.setSelected(true, animated: true)
                    }
                    annotationView?.displayPriority = .required
                }
                return annotationView
            }
            
            func setCenter(mapView: MKMapView, landmark: Landmark) {
                let centerCoordinates = getCenterCoordinates(landmark: control.userData.mainMapSelectedLandmark!)
                if centerCoordinates != nil {
                    mapView.setCenter(centerCoordinates!, animated: true)
                }
            }
            
            func getCenterCoordinates(landmark: Landmark) -> CLLocationCoordinate2D? {
                return landmark.locationCoordinate
            }
            
            func mapView(_ mapView: MKMapView,
                         didSelect view: MKAnnotationView) {
                let annotation = view.annotation as? LandmarkAnnotation
                
                if annotation != nil && annotation!.landmark != nil {
                    control.userData.mainMapSelectedLandmark = landmarkService.getLandmarkById(id: annotation!.landmark!.id)
                    control.userData.resetLandmarkDistance()
//                    setCenter(mapView: mapView, landmark: control.userData.mainMapSelectedLandmark!)
                }
            }
            
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polygon = overlay as? SelectablePolyline{
                    let polygonRenderer = MKPolylineRenderer(polyline: polygon)
                    if polygon.selected {
                        polygonRenderer.strokeColor = TRAIL_SELECTED
                        polygonRenderer.lineWidth = 2
                        polygonRenderer.lineDashPattern = [LINE_DASH_PATTERN, LINE_DASH_PATTERN]
                    } else {
                        polygonRenderer.strokeColor = TRAIL_DESELECTED
                        polygonRenderer.lineWidth = 2
                        polygonRenderer.lineDashPattern = [LINE_DASH_PATTERN, LINE_DASH_PATTERN]
                    }
                    
                    return polygonRenderer
                }
                return MKOverlayRenderer(overlay: overlay)
            }
            
            
        }
    
    private func updateAnnotations(from mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations)
        let newAnnotations = landmarks.map { LandmarkAnnotation(landmark: $0) }
        mapView.addAnnotations(newAnnotations)
    }
    
    private func addBoundary(from mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        
        let trailLandmarks = self.landmarks.filter {l in
            l.category == Landmark.Category.Trail
            }
        
        if trailLandmarks.count > 0 {
            trailLandmarks.forEach{ trail in
                let trail = landmarkService.getTrailById(id: trail.id)
                var selected = false
                if self.userData.mainMapSelectedLandmark != nil && trail!.id == self.userData.mainMapSelectedLandmark!.id{
                    selected = true
                }
                var points = trail!.boundaryCoordinates.map{CLLocationCoordinate2D(
                                    latitude: $0.latitude,
                                    longitude: $0.longitude)}
                if !trail!.isOpen {
                    points.append(CLLocationCoordinate2D(latitude: points[0].latitude, longitude: points[0].longitude))
                }
                let polygon = SelectablePolyline(coordinates:points, count: points.count)
                polygon.selected = selected
                mapView.addOverlay(polygon)
                
            }
            
        }
    }
    
}

class SelectablePolyline: MKPolyline {
    var selected = false
}

// TODO is this even being used?
struct MainMapView_Previews: PreviewProvider {
    static var previews: some View {
        // TODO get lat, long from configuration file
        MainMapView(coordinate: CLLocationCoordinate2D(
            latitude: 40.2464,
            longitude: -75.1784), landmarks: landmarkService.getLandmarks())
    }
}

