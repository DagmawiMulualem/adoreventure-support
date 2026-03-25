//
//  TravelMap3DView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import SceneKit
import Combine

struct TravelMap3DView: UIViewRepresentable {
    @ObservedObject var travelMapService: TravelMapService
    @Binding var selectedCountry: Country?
    @Binding var showingCountryDetail: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        context.coordinator.sceneView = sceneView
        
        // Configure the scene view
        sceneView.backgroundColor = UIColor.clear
        sceneView.allowsCameraControl = false // Disable default camera control to avoid conflicts
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 30 // Reduce FPS to prevent hangs
        
        // Create and configure the scene
        let scene = context.coordinator.createMapScene()
        sceneView.scene = scene
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Add pan gesture for camera control
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        // Add pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update pins based on travel data - use async to avoid state modification during view update
        Task { @MainActor in
            context.coordinator.updateMapPins(travelMapService: travelMapService)
            context.coordinator.updateCountryColors()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        let parent: TravelMap3DView
        
        // SceneKit references - moved from @State to Coordinator
        var sceneView: SCNView?
        var mapNode: SCNNode?
        var pinNodes: [String: SCNNode] = [:]
        
        init(_ parent: TravelMap3DView) {
            self.parent = parent
        }
        
        // MARK: - Scene Creation
        
        func createMapScene() -> SCNScene {
            let scene = SCNScene()
            
            // Create the map plane
            let mapGeometry = SCNPlane(width: 4, height: 2)
            mapGeometry.firstMaterial?.diffuse.contents = createWorldMapTexture()
            mapGeometry.firstMaterial?.isDoubleSided = false
            mapGeometry.firstMaterial?.lightingModel = .lambert
            
            let mapNode = SCNNode(geometry: mapGeometry)
            mapNode.position = SCNVector3(0, 0, 0)
            mapNode.eulerAngles = SCNVector3(-Float.pi/6, 0, 0) // Tilt the map for 3D effect
            
            // Add subtle shadow
            mapNode.castsShadow = true
            
            scene.rootNode.addChildNode(mapNode)
            self.mapNode = mapNode
            
            // Add lighting
            setupLighting(in: scene)
            
            // Add camera
            setupCamera(in: scene)
            
            return scene
        }
        
        private func createWorldMapTexture() -> UIImage {
            // Create a more visible world map texture
            let size = CGSize(width: 2048, height: 1024)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                // Ocean background - darker blue for better contrast
                UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // Continents - lighter colors for visibility
                UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0).setFill()
                
                // North America - more detailed shape
                let northAmerica = UIBezierPath()
                northAmerica.move(to: CGPoint(x: 150, y: 200))
                northAmerica.addLine(to: CGPoint(x: 200, y: 150))
                northAmerica.addLine(to: CGPoint(x: 300, y: 120))
                northAmerica.addLine(to: CGPoint(x: 400, y: 140))
                northAmerica.addLine(to: CGPoint(x: 450, y: 200))
                northAmerica.addLine(to: CGPoint(x: 480, y: 300))
                northAmerica.addLine(to: CGPoint(x: 450, y: 400))
                northAmerica.addLine(to: CGPoint(x: 400, y: 450))
                northAmerica.addLine(to: CGPoint(x: 300, y: 480))
                northAmerica.addLine(to: CGPoint(x: 200, y: 460))
                northAmerica.addLine(to: CGPoint(x: 150, y: 400))
                northAmerica.addLine(to: CGPoint(x: 120, y: 300))
                northAmerica.close()
                northAmerica.fill()
                
                // South America
                let southAmerica = UIBezierPath()
                southAmerica.move(to: CGPoint(x: 350, y: 500))
                southAmerica.addLine(to: CGPoint(x: 400, y: 480))
                southAmerica.addLine(to: CGPoint(x: 450, y: 520))
                southAmerica.addLine(to: CGPoint(x: 480, y: 600))
                southAmerica.addLine(to: CGPoint(x: 450, y: 750))
                southAmerica.addLine(to: CGPoint(x: 400, y: 850))
                southAmerica.addLine(to: CGPoint(x: 350, y: 900))
                southAmerica.addLine(to: CGPoint(x: 300, y: 850))
                southAmerica.addLine(to: CGPoint(x: 280, y: 750))
                southAmerica.addLine(to: CGPoint(x: 300, y: 600))
                southAmerica.addLine(to: CGPoint(x: 320, y: 520))
                southAmerica.close()
                southAmerica.fill()
                
                // Europe
                let europe = UIBezierPath()
                europe.move(to: CGPoint(x: 900, y: 150))
                europe.addLine(to: CGPoint(x: 950, y: 120))
                europe.addLine(to: CGPoint(x: 1000, y: 130))
                europe.addLine(to: CGPoint(x: 1050, y: 180))
                europe.addLine(to: CGPoint(x: 1100, y: 250))
                europe.addLine(to: CGPoint(x: 1080, y: 350))
                europe.addLine(to: CGPoint(x: 1000, y: 400))
                europe.addLine(to: CGPoint(x: 950, y: 380))
                europe.addLine(to: CGPoint(x: 900, y: 350))
                europe.addLine(to: CGPoint(x: 880, y: 250))
                europe.close()
                europe.fill()
                
                // Africa
                let africa = UIBezierPath()
                africa.move(to: CGPoint(x: 950, y: 350))
                africa.addLine(to: CGPoint(x: 1000, y: 320))
                africa.addLine(to: CGPoint(x: 1050, y: 340))
                africa.addLine(to: CGPoint(x: 1100, y: 400))
                africa.addLine(to: CGPoint(x: 1150, y: 500))
                africa.addLine(to: CGPoint(x: 1120, y: 650))
                africa.addLine(to: CGPoint(x: 1080, y: 750))
                africa.addLine(to: CGPoint(x: 1000, y: 800))
                africa.addLine(to: CGPoint(x: 950, y: 780))
                africa.addLine(to: CGPoint(x: 900, y: 700))
                africa.addLine(to: CGPoint(x: 880, y: 600))
                africa.addLine(to: CGPoint(x: 900, y: 500))
                africa.addLine(to: CGPoint(x: 920, y: 400))
                africa.close()
                africa.fill()
                
                // Asia
                let asia = UIBezierPath()
                asia.move(to: CGPoint(x: 1100, y: 100))
                asia.addLine(to: CGPoint(x: 1200, y: 80))
                asia.addLine(to: CGPoint(x: 1400, y: 90))
                asia.addLine(to: CGPoint(x: 1600, y: 120))
                asia.addLine(to: CGPoint(x: 1800, y: 150))
                asia.addLine(to: CGPoint(x: 1900, y: 200))
                asia.addLine(to: CGPoint(x: 1850, y: 350))
                asia.addLine(to: CGPoint(x: 1700, y: 450))
                asia.addLine(to: CGPoint(x: 1500, y: 500))
                asia.addLine(to: CGPoint(x: 1300, y: 480))
                asia.addLine(to: CGPoint(x: 1200, y: 400))
                asia.addLine(to: CGPoint(x: 1150, y: 300))
                asia.addLine(to: CGPoint(x: 1120, y: 200))
                asia.close()
                asia.fill()
                
                // Australia
                let australia = UIBezierPath()
                australia.move(to: CGPoint(x: 1400, y: 650))
                australia.addLine(to: CGPoint(x: 1500, y: 630))
                australia.addLine(to: CGPoint(x: 1600, y: 650))
                australia.addLine(to: CGPoint(x: 1700, y: 680))
                australia.addLine(to: CGPoint(x: 1750, y: 750))
                australia.addLine(to: CGPoint(x: 1700, y: 820))
                australia.addLine(to: CGPoint(x: 1600, y: 850))
                australia.addLine(to: CGPoint(x: 1500, y: 830))
                australia.addLine(to: CGPoint(x: 1400, y: 800))
                australia.addLine(to: CGPoint(x: 1350, y: 750))
                australia.addLine(to: CGPoint(x: 1380, y: 700))
                australia.close()
                australia.fill()
                
                // Add some grid lines for reference
                UIColor.white.withAlphaComponent(0.1).setStroke()
                let gridPath = UIBezierPath()
                
                // Vertical lines
                for i in 0...8 {
                    let x = CGFloat(i) * size.width / 8
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                // Horizontal lines
                for i in 0...4 {
                    let y = CGFloat(i) * size.height / 4
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                
                gridPath.stroke()
            }
        }
        
        private func setupLighting(in scene: SCNScene) {
            // Ambient light - brighter for better visibility
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = UIColor.white
            ambientLight.intensity = 800
            
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)
            
            // Directional light for depth
            let directionalLight = SCNLight()
            directionalLight.type = .directional
            directionalLight.color = UIColor.white
            directionalLight.intensity = 1200
            directionalLight.castsShadow = false // Disable shadows for better visibility
            directionalLight.shadowMode = .forward
            directionalLight.shadowColor = UIColor.black.withAlphaComponent(0.2)
            
            let directionalNode = SCNNode()
            directionalNode.light = directionalLight
            directionalNode.position = SCNVector3(2, 5, 3)
            directionalNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(directionalNode)
        }
        
        private func setupCamera(in scene: SCNScene) {
            let camera = SCNCamera()
            camera.fieldOfView = 60
            camera.usesOrthographicProjection = false
            
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 2, 4)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            
            scene.rootNode.addChildNode(cameraNode)
        }
        
        // MARK: - Map Updates
        
        // Track last known travel data state to avoid unnecessary pin rebuilds
        private var lastVisitedCountryIds: Set<String> = []
        private var lastWishlistCountryIds: Set<String> = []
        private var lastShowDemoPins: Bool = false
        
        @MainActor
        func updateMapPins(travelMapService: TravelMapService) {
            guard let mapNode = mapNode else { return }
            
            // Get current travel data state
            let currentVisitedIds = Set(travelMapService.getCountries(by: .visited).map { $0.id })
            let currentWishlistIds = Set(travelMapService.getCountries(by: .wishlist).map { $0.id })
            let currentShowDemoPins = currentVisitedIds.isEmpty && currentWishlistIds.isEmpty
            
            // Check if travel data has actually changed
            let dataChanged = currentVisitedIds != lastVisitedCountryIds ||
                             currentWishlistIds != lastWishlistCountryIds ||
                             currentShowDemoPins != lastShowDemoPins
            
            // Only rebuild pins if data has changed
            guard dataChanged else { return }
            
            // Update tracked state
            lastVisitedCountryIds = currentVisitedIds
            lastWishlistCountryIds = currentWishlistIds
            lastShowDemoPins = currentShowDemoPins
            
            // Remove existing pins
            pinNodes.values.forEach { $0.removeFromParentNode() }
            pinNodes.removeAll()
            
            // Add pins for visited countries
            for country in travelMapService.getCountries(by: .visited) {
                addPin(for: country, at: country.coordinates)
            }
            
            // Add pins for wishlist countries
            for country in travelMapService.getCountries(by: .wishlist) {
                addPin(for: country, at: country.coordinates, isWishlist: true)
            }
            
            // Add some demo pins for testing if no countries are marked yet
            if currentShowDemoPins {
                addDemoPins()
            }
        }
        
        func updateCountryColors() {
            // This would update the map texture based on travel status
            // For now, we'll use pins to indicate status
            // In a full implementation, you'd modify the map texture dynamically
        }
        
        private func addDemoPins() {
            // Add a few demo pins to show the functionality
            let demoCountries = [
                ("US", CountryCoordinates(latitude: 39.8283, longitude: -98.5795)), // United States
                ("FR", CountryCoordinates(latitude: 46.2276, longitude: 2.2137)),  // France
                ("JP", CountryCoordinates(latitude: 36.2048, longitude: 138.2529)), // Japan
                ("AU", CountryCoordinates(latitude: -25.2744, longitude: 133.7751)) // Australia
            ]
            
            for (countryCode, coordinates) in demoCountries {
                addDemoPin(at: coordinates, countryCode: countryCode)
            }
        }
        
        private func addDemoPin(at coordinates: CountryCoordinates, countryCode: String) {
            guard let mapNode = mapNode else { return }
            
            // Create pin geometry
            let pinGeometry = SCNCone(topRadius: 0.02, bottomRadius: 0.05, height: 0.1)
            pinGeometry.firstMaterial?.diffuse.contents = UIColor.systemOrange
            pinGeometry.firstMaterial?.specular.contents = UIColor.white
            pinGeometry.firstMaterial?.shininess = 0.8
            
            let pinNode = SCNNode(geometry: pinGeometry)
            
            // Store country ID in node name for reliable identification
            pinNode.name = "demo_\(countryCode)"
            
            // Position the pin on the map
            let x = Float((coordinates.normalizedX - 0.5) * 4) // Map width is 4
            let y = Float((coordinates.normalizedY - 0.5) * 2) // Map height is 2
            let z = Float(0.05) // Slightly above the map surface
            
            pinNode.position = SCNVector3(x, y, z)
            
            // Add country code as text
            let textGeometry = SCNText(string: countryCode, extrusionDepth: 0.01)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            textGeometry.font = UIFont.systemFont(ofSize: 0.1, weight: .medium)
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = SCNVector3(0, 0.15, 0)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            
            pinNode.addChildNode(textNode)
            
            // Add to scene
            mapNode.addChildNode(pinNode)
            pinNodes["demo_\(countryCode)"] = pinNode
            
            // Add entrance animation
            animatePinEntrance(pinNode)
        }
        
        private func addPin(for country: Country, at coordinates: CountryCoordinates, isWishlist: Bool = false) {
            guard let mapNode = mapNode else { return }
            
            // Create pin geometry
            let pinGeometry = SCNCone(topRadius: 0.02, bottomRadius: 0.05, height: 0.1)
            pinGeometry.firstMaterial?.diffuse.contents = isWishlist ? UIColor.systemBlue : UIColor.systemGreen
            pinGeometry.firstMaterial?.specular.contents = UIColor.white
            pinGeometry.firstMaterial?.shininess = 0.8
            
            let pinNode = SCNNode(geometry: pinGeometry)
            
            // Store country ID in node name for reliable identification
            pinNode.name = country.id
            
            // Position the pin on the map
            let x = Float((coordinates.normalizedX - 0.5) * 4) // Map width is 4
            let y = Float((coordinates.normalizedY - 0.5) * 2) // Map height is 2
            let z = Float(0.05) // Slightly above the map surface
            
            pinNode.position = SCNVector3(x, y, z)
            
            // Add country name as text
            let textGeometry = SCNText(string: country.name, extrusionDepth: 0.01)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            textGeometry.font = UIFont.systemFont(ofSize: 0.1, weight: .medium)
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = SCNVector3(0, 0.15, 0)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            
            pinNode.addChildNode(textNode)
            
            // Add to scene
            mapNode.addChildNode(pinNode)
            pinNodes[country.id] = pinNode
            
            // Add entrance animation
            animatePinEntrance(pinNode)
        }
        
        // MARK: - Animations
        
        private func animatePinEntrance(_ pinNode: SCNNode) {
            // Scale animation
            pinNode.scale = SCNVector3(0.1, 0.1, 0.1)
            
            let scaleAnimation = CABasicAnimation(keyPath: "scale")
            scaleAnimation.fromValue = NSValue(scnVector3: SCNVector3(0.1, 0.1, 0.1))
            scaleAnimation.toValue = NSValue(scnVector3: SCNVector3(1, 1, 1))
            scaleAnimation.duration = 0.5
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Bounce effect
            let bounceAnimation = CABasicAnimation(keyPath: "position.y")
            bounceAnimation.fromValue = pinNode.position.y - 0.2
            bounceAnimation.toValue = pinNode.position.y
            bounceAnimation.duration = 0.6
            bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Add animations
            pinNode.addAnimation(scaleAnimation, forKey: "scale")
            pinNode.addAnimation(bounceAnimation, forKey: "bounce")
            
            // Add ripple effect
            addRippleEffect(at: pinNode.position)
        }
        
        private func addRippleEffect(at position: SCNVector3) {
            guard let mapNode = mapNode else { return }
            
            let rippleGeometry = SCNPlane(width: 0.2, height: 0.2)
            rippleGeometry.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.3)
            rippleGeometry.firstMaterial?.isDoubleSided = true
            
            let rippleNode = SCNNode(geometry: rippleGeometry)
            rippleNode.position = SCNVector3(position.x, position.y, position.z + 0.01)
            rippleNode.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
            
            mapNode.addChildNode(rippleNode)
            
            // Animate ripple
            let scaleAnimation = CABasicAnimation(keyPath: "scale")
            scaleAnimation.fromValue = NSValue(scnVector3: SCNVector3(0.1, 0.1, 1))
            scaleAnimation.toValue = NSValue(scnVector3: SCNVector3(2, 2, 1))
            scaleAnimation.duration = 1.0
            
            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 0.8
            opacityAnimation.toValue = 0.0
            opacityAnimation.duration = 1.0
            
            let group = CAAnimationGroup()
            group.animations = [scaleAnimation, opacityAnimation]
            group.duration = 1.0
            group.isRemovedOnCompletion = true
            
            rippleNode.addAnimation(group, forKey: "ripple")
            
            // Remove ripple after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                rippleNode.removeFromParentNode()
            }
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = sceneView else { return }
            
            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: nil)
            
            // Search through ALL hit results to find a pin (not just the first)
            // The first hit might be the map plane, but a pin could be in later results
            var foundPin: SCNNode?
            var foundCountryId: String?
            
            for hit in hitResults {
                let hitNode = hit.node
                var pinNode: SCNNode?
                
                // Check if the hit node itself is a pin (has a name property set)
                if hitNode.name != nil {
                    pinNode = hitNode
                } else if let parentNode = hitNode.parent, parentNode.name != nil {
                    // Check if parent is a pin
                    pinNode = parentNode
                } else {
                    // Check if any ancestor is a pin by looking for name property
                    var currentNode: SCNNode? = hitNode.parent
                    while let node = currentNode {
                        if node.name != nil {
                            pinNode = node
                            break
                        }
                        currentNode = node.parent
                    }
                }
                
                // If we found a pin, get its country ID from the name property
                if let pin = pinNode, let countryId = pin.name {
                    foundPin = pin
                    foundCountryId = countryId
                    break
                }
            }
            
            // Handle pin tap if found
            if let pin = foundPin, let countryId = foundCountryId {
                Task { @MainActor in
                    // Handle demo pins
                    if countryId.hasPrefix("demo_") {
                        let countryCode = String(countryId.dropFirst(5)) // Remove "demo_" prefix
                        if let country = parent.travelMapService.countries.first(where: { $0.code == countryCode }) {
                            parent.selectedCountry = country
                            parent.showingCountryDetail = true
                            animatePinSelection(pin)
                        }
                    } else {
                        // Handle real country pins
                        if let country = parent.travelMapService.countries.first(where: { $0.id == countryId }) {
                            parent.selectedCountry = country
                            parent.showingCountryDetail = true
                            animatePinSelection(pin)
                        }
                    }
                }
            } else {
                // No pin found - tap on empty map area, add a ripple effect
                addTapRipple(at: location, in: sceneView)
            }
        }
        
        private func addTapRipple(at location: CGPoint, in sceneView: SCNView) {
            guard let mapNode = mapNode else { return }
            
            // Convert screen coordinates to world coordinates
            let hitResults = sceneView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest])
            if let hit = hitResults.first {
                let worldPosition = hit.worldCoordinates
                
                // Create ripple effect
                let rippleGeometry = SCNPlane(width: 0.1, height: 0.1)
                rippleGeometry.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.5)
                rippleGeometry.firstMaterial?.isDoubleSided = true
                
                let rippleNode = SCNNode(geometry: rippleGeometry)
                rippleNode.position = SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z + 0.01)
                rippleNode.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
                
                mapNode.addChildNode(rippleNode)
                
                // Animate ripple
                let scaleAnimation = CABasicAnimation(keyPath: "scale")
                scaleAnimation.fromValue = NSValue(scnVector3: SCNVector3(0.1, 0.1, 1))
                scaleAnimation.toValue = NSValue(scnVector3: SCNVector3(3, 3, 1))
                scaleAnimation.duration = 0.8
                
                let opacityAnimation = CABasicAnimation(keyPath: "opacity")
                opacityAnimation.fromValue = 0.8
                opacityAnimation.toValue = 0.0
                opacityAnimation.duration = 0.8
                
                let group = CAAnimationGroup()
                group.animations = [scaleAnimation, opacityAnimation]
                group.duration = 0.8
                group.isRemovedOnCompletion = true
                
                rippleNode.addAnimation(group, forKey: "ripple")
                
                // Remove ripple after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    rippleNode.removeFromParentNode()
                }
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            // Handle camera panning
            guard let sceneView = sceneView, gesture.state == .changed else { return }
            
            let translation = gesture.translation(in: sceneView)
            
            // Implement camera rotation based on pan
            if let cameraNode = sceneView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
                let rotationSpeed: Float = 0.005 // Reduced speed to prevent jerky movement
                let rotationY = Float(translation.x) * rotationSpeed
                let rotationX = Float(translation.y) * rotationSpeed
                
                cameraNode.eulerAngles.y -= rotationY
                cameraNode.eulerAngles.x -= rotationX
                
                // Limit vertical rotation
                cameraNode.eulerAngles.x = max(-Float.pi/4, min(Float.pi/4, cameraNode.eulerAngles.x))
            }
            
            gesture.setTranslation(.zero, in: sceneView)
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            // Handle camera zoom
            guard let sceneView = sceneView, gesture.state == .changed else { return }
            
            let scale = gesture.scale
            if let cameraNode = sceneView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
                let currentDistance = cameraNode.position.z
                let newDistance = currentDistance / Float(scale)
                
                // Limit zoom range
                let minDistance: Float = 2.0
                let maxDistance: Float = 8.0
                cameraNode.position.z = max(minDistance, min(maxDistance, newDistance))
            }
            
            gesture.scale = 1.0
        }
        
        private func animatePinSelection(_ pinNode: SCNNode) {
            // Highlight animation
            let highlightAnimation = CABasicAnimation(keyPath: "opacity")
            highlightAnimation.fromValue = 1.0
            highlightAnimation.toValue = 0.5
            highlightAnimation.duration = 0.2
            highlightAnimation.autoreverses = true
            highlightAnimation.repeatCount = 2
            
            pinNode.addAnimation(highlightAnimation, forKey: "highlight")
        }
    }
}

// MARK: - Preview
#Preview {
    TravelMap3DView(
        travelMapService: TravelMapService.shared,
        selectedCountry: .constant(nil),
        showingCountryDetail: .constant(false)
    )
    .frame(height: 400)
}
