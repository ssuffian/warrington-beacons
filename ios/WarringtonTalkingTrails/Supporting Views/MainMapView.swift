//
//  Map.swift
//  WarringtonTalkingTrails
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

/// MapKit's marker is visible to accessibility, but its default activation does
/// not consistently select the annotation when VoiceOver is driving the map.
final class AccessibleLandmarkAnnotationView: MKMarkerAnnotationView {
    weak var owningMapView: MKMapView?

    override func accessibilityActivate() -> Bool {
        guard let annotation, let owningMapView else { return false }
        owningMapView.selectAnnotation(annotation, animated: true)
        return true
    }
}

func configureAccessibility(
    for view: AccessibleLandmarkAnnotationView,
    annotation: LandmarkAnnotation,
    mapView: MKMapView
) {
    view.owningMapView = mapView
    view.isAccessibilityElement = true
    view.accessibilityIdentifier = "landmark-map-pin-\(annotation.id)"
    view.accessibilityLabel = annotation.landmark?.trailModifiedName ?? annotation.title
    if let category = annotation.landmark?.category.friendlyValue() {
        view.accessibilityValue = category
    } else {
        view.accessibilityValue = nil
    }
    view.accessibilityHint = "Opens landmark information"
    view.accessibilityTraits = .button
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
        context.coordinator.loadKml(on: mapView)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        
        context.coordinator.control = self
        updateAnnotations(from: uiView)
        addBoundary(from: uiView, routes: context.coordinator.routes)
        
    }
    
    
    func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        final class Coordinator: NSObject, MKMapViewDelegate {
            var control: MainMapView
            var routes: [[CLLocationCoordinate2D]]?
            private var kmlTask: URLSessionDataTask?

            deinit { kmlTask?.cancel() }

            func loadKml(on mapView: MKMapView) {
                let url = URL(string: "https://trails.warringtoneac.org/talking-trails.kml")!
                let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
                kmlTask = URLSession.shared.dataTask(with: request) { [weak self, weak mapView] data, response, error in
                    guard error == nil, let data = data,
                          let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
                          let routes = TrailKmlParser.read(data) else { return }
                    DispatchQueue.main.async { [weak self, weak mapView] in
                        guard let self = self, let mapView = mapView else { return }
                        self.routes = routes
                        self.control.addBoundary(from: mapView, routes: routes)
                        // Permit panning to the new parks, outside the old fixed boundary.
                        mapView.setCameraBoundary(nil, animated: false)
                    }
                }
                kmlTask?.resume()
            }

            init(_ control: MainMapView) {
                self.control = control
            }
            
            
            func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                guard let annotation = annotation as? LandmarkAnnotation else { return nil }
                let identifier = "MainMapAnnotation\(annotation.id)"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? AccessibleLandmarkAnnotationView
                if annotationView == nil {
                    annotationView = AccessibleLandmarkAnnotationView(annotation: annotation, reuseIdentifier: identifier)
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
                if let annotationView {
                    configureAccessibility(for: annotationView, annotation: annotation, mapView: mapView)
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
    
    private func addBoundary(from mapView: MKMapView, routes: [[CLLocationCoordinate2D]]? = nil) {
        mapView.removeOverlays(mapView.overlays)
        if let routes = routes {
            for points in routes {
                let line = SelectablePolyline(coordinates: points, count: points.count)
                mapView.addOverlay(line)
            }
            return
        }
        
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

/// Only route geometry is read. KML pins never create or overwrite app landmarks.
final class TrailKmlParser: NSObject, XMLParserDelegate {
    private var stack = [String]()
    private var buffer = ""
    private var collecting = false
    private var valid = true
    private var routes = [[CLLocationCoordinate2D]]()

    static func read(_ data: Data) -> [[CLLocationCoordinate2D]]? {
        guard let text = String(data: data, encoding: .utf8),
              !text.uppercased().contains("<!DOCTYPE") else { return nil }
        let delegate = TrailKmlParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.valid, !delegate.routes.isEmpty else { return nil }
        return delegate.routes
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        stack.append(elementName)
        if elementName == "coordinates" && (stack.contains("LineString") || stack.contains("outerBoundaryIs")) {
            collecting = true
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "coordinates" && collecting {
            collecting = false
            var points = [CLLocationCoordinate2D]()
            for tuple in buffer.split(whereSeparator: { $0.isWhitespace }) {
                let values = tuple.split(separator: ",", omittingEmptySubsequences: false)
                guard values.count >= 2, let lon = Double(values[0]), let lat = Double(values[1]),
                      lon.isFinite, lat.isFinite, (-180...180).contains(lon), (-90...90).contains(lat) else {
                    valid = false
                    parser.abortParsing()
                    return
                }
                points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            if points.count < 2 { valid = false } else { routes.append(points) }
        }
        if !stack.isEmpty { stack.removeLast() }
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
