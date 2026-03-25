//
//  InteractiveTravelMapView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct InteractiveTravelMapView: UIViewRepresentable {
    @ObservedObject var travelMapService: TravelMapService
    @Binding var selectedCountry: Country?
    @Binding var showingCountryDetail: Bool
    var isInteractive: Bool = true // Default to interactive for backward compatibility
    
    func makeUIView(context: Context) -> MKMapView {
        print("🗺️ Creating MKMapView...")
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Configure map appearance
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Set initial view to show the world
        let worldRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
        )
        mapView.setRegion(worldRegion, animated: false)
        print("🗺️ Map region set to world view")
        
        // Store mapView reference and interactive state in coordinator
        context.coordinator.mapView = mapView
        context.coordinator.isInteractive = isInteractive
        
        // Only add tap gesture recognizer if map is interactive
        if isInteractive {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
            tapGesture.delegate = context.coordinator
            tapGesture.numberOfTapsRequired = 1
            tapGesture.numberOfTouchesRequired = 1
            mapView.addGestureRecognizer(tapGesture)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🗺️ Updating map annotations...")
        
        // Ensure mapView reference is set and sync interactive state
        if context.coordinator.mapView !== mapView {
            context.coordinator.mapView = mapView
        }
        context.coordinator.isInteractive = isInteractive
        
        // Update annotations based on travel data
        context.coordinator.updateMapAnnotations(mapView: mapView, travelMapService: travelMapService)
        print("🗺️ Map annotations updated")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let parent: InteractiveTravelMapView
        weak var mapView: MKMapView?
        var isInteractive: Bool = true
        
        // Track last known travel data state to avoid unnecessary annotation rebuilds
        private var lastVisitedCountryIds: Set<String> = []
        private var lastWishlistCountryIds: Set<String> = []
        private var lastVisitedStateIds: Set<String> = []
        private var lastWishlistStateIds: Set<String> = []
        
        init(_ parent: InteractiveTravelMapView) {
            self.parent = parent
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Only handle taps if they're not on an annotation view
            guard let mapView = mapView else { return true }
            let location = touch.location(in: mapView)
            let hitView = mapView.hitTest(location, with: nil)
            
            // If the tap is on an annotation view or its superview, let MapKit handle it
            var currentView: UIView? = hitView
            while let view = currentView {
                if view is MKAnnotationView {
                    return false
                }
                currentView = view.superview
            }
            
            // Allow the gesture for empty map areas
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition with MapKit's gestures
            return true
        }
        
        func updateMapAnnotations(mapView: MKMapView, travelMapService: TravelMapService) {
            // Get current travel data state
            let currentVisitedCountryIds = Set(travelMapService.getCountries(by: .visited).map { $0.id })
            let currentWishlistCountryIds = Set(travelMapService.getCountries(by: .wishlist).map { $0.id })
            let currentVisitedStateIds = Set(travelMapService.getStates(by: .visited).map { $0.id })
            let currentWishlistStateIds = Set(travelMapService.getStates(by: .wishlist).map { $0.id })
            
            // Check if travel data has actually changed
            let dataChanged = currentVisitedCountryIds != lastVisitedCountryIds ||
                             currentWishlistCountryIds != lastWishlistCountryIds ||
                             currentVisitedStateIds != lastVisitedStateIds ||
                             currentWishlistStateIds != lastWishlistStateIds
            
            // Only rebuild annotations if data has changed
            guard dataChanged else { return }
            
            // Update tracked state
            lastVisitedCountryIds = currentVisitedCountryIds
            lastWishlistCountryIds = currentWishlistCountryIds
            lastVisitedStateIds = currentVisitedStateIds
            lastWishlistStateIds = currentWishlistStateIds
            
            // Remove existing annotations
            mapView.removeAnnotations(mapView.annotations)
            
            // Add annotations for visited countries
            for country in travelMapService.getCountries(by: .visited) {
                let annotation = CountryAnnotation(country: country, status: .visited)
                mapView.addAnnotation(annotation)
            }
            
            // Add annotations for visited states
            for state in travelMapService.getStates(by: .visited) {
                let annotation = TravelStateAnnotation(state: state, status: .visited)
                mapView.addAnnotation(annotation)
            }
            
            // Add annotations for wishlist countries
            for country in travelMapService.getCountries(by: .wishlist) {
                let annotation = CountryAnnotation(country: country, status: .wishlist)
                mapView.addAnnotation(annotation)
            }
            
            // Add annotations for wishlist states
            for state in travelMapService.getStates(by: .wishlist) {
                let annotation = TravelStateAnnotation(state: state, status: .wishlist)
                mapView.addAnnotation(annotation)
            }
            
            // Always add demo annotations for better user experience and testing
            addDemoAnnotations(mapView)
        }
        
        private func addDemoAnnotations(_ mapView: MKMapView) {
            let demoCountries = [
                ("US", CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), "United States"),
                ("FR", CLLocationCoordinate2D(latitude: 46.2276, longitude: 2.2137), "France"),
                ("JP", CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529), "Japan"),
                ("AU", CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751), "Australia"),
                ("BR", CLLocationCoordinate2D(latitude: -14.2350, longitude: -51.9253), "Brazil"),
                ("IN", CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), "India")
            ]
            
            for (code, coordinate, name) in demoCountries {
                let demoCountry = Country(
                    id: code,
                    name: name,
                    code: code,
                    continent: .asia, // Default continent
                    coordinates: CountryCoordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
                )
                let annotation = CountryAnnotation(country: demoCountry, status: .untouched, isDemo: true)
                mapView.addAnnotation(annotation)
            }
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            
            // Find the nearest location (state or country) to the tap location
            if let nearestLocation = findNearestLocation(to: coordinate) {
                Task { @MainActor in
                    if let country = nearestLocation as? Country {
                        print("🗺️ Selected country: \(country.name)")
                        parent.selectedCountry = country
                        parent.showingCountryDetail = true
                    } else if let state = nearestLocation as? TravelState {
                        print("🗺️ Selected state: \(state.name) in \(state.countryCode)")
                        // Convert state to country for the detail view
                        if let country = parent.travelMapService.countries.first(where: { $0.code == state.countryCode }) {
                            parent.selectedCountry = country
                            parent.showingCountryDetail = true
                        }
                    }
                }
            } else {
                print("🗺️ No location found near tap at: \(coordinate.latitude), \(coordinate.longitude)")
            }
        }
        
        private func findNearestLocation(to coordinate: CLLocationCoordinate2D) -> Any? {
            let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            var nearestLocation: Any?
            var shortestDistance: CLLocationDistance = Double.infinity
            
            // First check states (more specific) - use smaller distance threshold
            for state in parent.travelMapService.states {
                let stateLocation = CLLocation(latitude: state.coordinates.latitude, longitude: state.coordinates.longitude)
                let distance = tapLocation.distance(from: stateLocation)
                
                // Only consider states within a reasonable distance (300km for better accuracy)
                if distance < 300000 && distance < shortestDistance {
                    shortestDistance = distance
                    nearestLocation = state
                }
            }
            
            // If no state found, check countries with a larger threshold
            if nearestLocation == nil {
                for country in parent.travelMapService.countries {
                    let countryLocation = CLLocation(latitude: country.coordinates.latitude, longitude: country.coordinates.longitude)
                    let distance = tapLocation.distance(from: countryLocation)
                    
                    // Only consider countries within a reasonable distance (1000km)
                    if distance < 1000000 && distance < shortestDistance {
                        shortestDistance = distance
                        nearestLocation = country
                    }
                }
            }
            
            // If still no location found, try a more lenient approach for countries
            if nearestLocation == nil {
                for country in parent.travelMapService.countries {
                    let countryLocation = CLLocation(latitude: country.coordinates.latitude, longitude: country.coordinates.longitude)
                    let distance = tapLocation.distance(from: countryLocation)
                    
                    // Use a much larger threshold for remote areas (2000km)
                    if distance < 2000000 && distance < shortestDistance {
                        shortestDistance = distance
                        nearestLocation = country
                    }
                }
            }
            
            return nearestLocation
        }
        
        // MARK: - MKMapViewDelegate
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "LocationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                // Handle country annotations
                if let countryAnnotation = annotation as? CountryAnnotation {
                    configureMarker(markerView, for: countryAnnotation.status, isState: false)
                }
                // Handle state annotations
                else if let stateAnnotation = annotation as? TravelStateAnnotation {
                    configureMarker(markerView, for: stateAnnotation.status, isState: true)
                }
                
                // Add callout button
                let button = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = button
            }
            
            return annotationView
        }
        
        private func configureMarker(_ markerView: MKMarkerAnnotationView, for status: TravelStatus, isState: Bool) {
            // Configure marker appearance based on status
            switch status {
            case .visited:
                markerView.markerTintColor = .systemGreen
                markerView.glyphImage = UIImage(systemName: "checkmark.circle.fill")
            case .wishlist:
                markerView.markerTintColor = .systemBlue
                markerView.glyphImage = UIImage(systemName: "heart.fill")
            case .skipped:
                markerView.markerTintColor = .systemRed
                markerView.glyphImage = UIImage(systemName: "xmark.circle.fill")
            case .untouched:
                markerView.markerTintColor = .systemOrange
                markerView.glyphImage = UIImage(systemName: isState ? "location.circle.fill" : "mappin.circle.fill")
            }
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            Task { @MainActor in
                if let countryAnnotation = view.annotation as? CountryAnnotation {
                    parent.selectedCountry = countryAnnotation.country
                    parent.showingCountryDetail = true
                } else if let stateAnnotation = view.annotation as? TravelStateAnnotation {
                    // Convert state to country for the detail view
                    if let country = parent.travelMapService.countries.first(where: { $0.code == stateAnnotation.state.countryCode }) {
                        parent.selectedCountry = country
                        parent.showingCountryDetail = true
                    }
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Add a subtle animation when selecting
            UIView.animate(withDuration: 0.2) {
                view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    view.transform = CGAffineTransform.identity
                }
            }
            
            // Only handle annotation selection if map is interactive
            guard isInteractive else { return }
            
            // Handle annotation selection
            Task { @MainActor in
                if let countryAnnotation = view.annotation as? CountryAnnotation {
                    print("🗺️ Selected country annotation: \(countryAnnotation.country.name)")
                    parent.selectedCountry = countryAnnotation.country
                    parent.showingCountryDetail = true
                } else if let stateAnnotation = view.annotation as? TravelStateAnnotation {
                    print("🗺️ Selected state annotation: \(stateAnnotation.state.name)")
                    if let country = parent.travelMapService.countries.first(where: { $0.code == stateAnnotation.state.countryCode }) {
                        parent.selectedCountry = country
                        parent.showingCountryDetail = true
                    }
                }
            }
        }
    }
}

// MARK: - Country Annotation
class CountryAnnotation: NSObject, MKAnnotation {
    let country: Country
    let status: TravelStatus
    let isDemo: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: country.coordinates.latitude, longitude: country.coordinates.longitude)
    }
    
    var title: String? {
        return country.name
    }
    
    var subtitle: String? {
        if isDemo {
            return "Tap to mark as visited"
        } else {
            return status.displayName
        }
    }
    
    init(country: Country, status: TravelStatus, isDemo: Bool = false) {
        self.country = country
        self.status = status
        self.isDemo = isDemo
        super.init()
    }
}

// MARK: - State Annotation
class TravelStateAnnotation: NSObject, MKAnnotation {
    let state: TravelState
    let status: TravelStatus
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: state.coordinates.latitude, longitude: state.coordinates.longitude)
    }
    
    var title: String? {
        return state.name
    }
    
    var subtitle: String? {
        return "\(status.displayName) • State"
    }
    
    init(state: TravelState, status: TravelStatus) {
        self.state = state
        self.status = status
        super.init()
    }
}

#Preview {
    InteractiveTravelMapView(
        travelMapService: TravelMapService.shared,
        selectedCountry: .constant(nil),
        showingCountryDetail: .constant(false)
    )
    .frame(height: 400)
}
