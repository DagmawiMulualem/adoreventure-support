//
//  TravelMapService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import SwiftUI
import CoreLocation

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class TravelMapService: ObservableObject {
    static let shared = TravelMapService()
    
    // MARK: - Published Properties
    @Published var countries: [Country] = []
    @Published var states: [TravelState] = []
    @Published var travelStatistics = TravelStatistics()
    @Published var achievements: [Achievement] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var userId: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        // Initialize with all countries and states from static data
        self.countries = CountryData.allCountries
        self.states = CountryData.allStates()
        self.achievements = AchievementData.allAchievements
        
        // Listen for authentication changes
        NotificationCenter.default.publisher(for: .authStateChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.setupUserData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Set up user data when authenticated
    func setupUserData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.userId = nil
            resetToDefaultState()
            return
        }
        
        self.userId = userId
        await loadUserTravelData()
    }
    
    /// Load user's travel data from Firestore
    func loadUserTravelData() async {
        guard let userId = userId else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load user's travel data
            let travelDataDoc = try await db.collection("users").document(userId).collection("travelData").document("countries").getDocument()
            
            if let data = travelDataDoc.data() {
                await updateCountriesFromFirestore(data)
            }
            
            // Load achievements
            let achievementsDoc = try await db.collection("users").document(userId).collection("travelData").document("achievements").getDocument()
            
            if let achievementsData = achievementsDoc.data() {
                await updateAchievementsFromFirestore(achievementsData)
            }
            
            // Update statistics
            updateTravelStatistics()
            
        } catch {
            errorMessage = "Failed to load travel data: \(error.localizedDescription)"
            print("❌ TravelMapService: Error loading travel data - \(error)")
        }
        
        isLoading = false
    }
    
    /// Update country travel status
    func updateCountryStatus(_ country: Country, status: TravelStatus, notes: String? = nil, photos: [String]? = nil) async {
        guard let userId = userId else { return }
        
        // Update local data
        if let index = countries.firstIndex(where: { $0.id == country.id }) {
            countries[index].travelStatus = status
            countries[index].visitDate = status == .visited ? Date() : nil
            countries[index].notes = notes
            if let photos = photos {
                countries[index].photos = photos
            }
        }
        
        // Update Firestore
        do {
            var countryData: [String: Any] = [
                "status": status.rawValue,
                "visitDate": status == .visited ? Timestamp(date: Date()) : FieldValue.delete(),
                "notes": notes ?? FieldValue.delete(),
                "lastUpdated": Timestamp(date: Date())
            ]
            
            if let photos = photos {
                countryData["photos"] = photos
            }
            
            try await db.collection("users").document(userId).collection("travelData").document("countries").setData([
                country.id: countryData
            ], merge: true)
            
            // Update statistics and check achievements
            updateTravelStatistics()
            await checkAndUpdateAchievements()
            
        } catch {
            errorMessage = "Failed to update country status: \(error.localizedDescription)"
            print("❌ TravelMapService: Error updating country status - \(error)")
        }
    }
    
    /// Add a travel pin for a country
    func addTravelPin(for country: Country, notes: String? = nil, photos: [String] = []) async {
        guard let userId = userId else { return }
        
        let pin = TravelPin(countryId: country.id, notes: notes, photos: photos)
        
        do {
            let pinData: [String: Any] = [
                "countryId": pin.countryId,
                "visitDate": Timestamp(date: pin.visitDate),
                "notes": pin.notes ?? FieldValue.delete(),
                "photos": pin.photos,
                "isVerified": pin.isVerified,
                "createdAt": Timestamp(date: Date())
            ]
            
            try await db.collection("users").document(userId).collection("travelPins").document(pin.id.uuidString).setData(pinData)
            
            // Update country status to visited if not already
            if country.travelStatus != .visited {
                await updateCountryStatus(country, status: .visited, notes: notes, photos: photos.isEmpty ? nil : photos)
            }
            
        } catch {
            errorMessage = "Failed to add travel pin: \(error.localizedDescription)"
            print("❌ TravelMapService: Error adding travel pin - \(error)")
        }
    }
    
    /// Get countries by status
    func getCountries(by status: TravelStatus) -> [Country] {
        return countries.filter { $0.travelStatus == status }
    }
    
    /// Get countries by continent
    func getCountries(in continent: Continent) -> [Country] {
        return countries.filter { $0.continent == continent }
    }
    
    /// Get states by status
    func getStates(by status: TravelStatus) -> [TravelState] {
        return states.filter { $0.travelStatus == status }
    }
    
    /// Get states by country
    func getStates(in country: Country) -> [TravelState] {
        return states.filter { $0.countryCode == country.code }
    }
    
    /// Add a custom country with geocoding
    func addCustomCountry(name: String) async -> Country? {
        // Check if country already exists
        if let existing = countries.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        
        // Geocode the country name to get coordinates
        let geocoder = CLGeocoder()
        var coordinates = CountryCoordinates(latitude: 20.0, longitude: 0.0) // Default fallback
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(name)
            if let placemark = placemarks.first,
               let location = placemark.location {
                coordinates = CountryCoordinates(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                print("🗺️ Geocoded '\(name)' to: \(coordinates.latitude), \(coordinates.longitude)")
            }
        } catch {
            print("🗺️ Geocoding failed for '\(name)': \(error.localizedDescription)")
            // Use default coordinates if geocoding fails
        }
        
        // Generate a unique ID and code
        let customId = "custom_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let customCode = String(name.prefix(2)).uppercased()
        
        // Determine continent from coordinates (rough approximation)
        let continent: Continent = {
            if coordinates.latitude < -20 && coordinates.longitude > 110 && coordinates.longitude < 180 {
                return .oceania
            } else if coordinates.latitude > 35 && coordinates.longitude > -10 && coordinates.longitude < 40 {
                return .europe
            } else if coordinates.latitude > -35 && coordinates.latitude < 37 && coordinates.longitude > -20 && coordinates.longitude < 52 {
                return .africa
            } else if coordinates.latitude > 10 && coordinates.longitude > 60 && coordinates.longitude < 150 {
                return .asia
            } else if coordinates.latitude > 7 && coordinates.longitude > -180 && coordinates.longitude < -30 {
                return .northAmerica
            } else if coordinates.latitude < 13 && coordinates.longitude > -90 && coordinates.longitude < -30 {
                return .southAmerica
            } else {
                return .asia // Default
            }
        }()
        
        // Create the custom country
        let customCountry = Country(
            id: customId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            code: customCode,
            continent: continent,
            coordinates: coordinates
        )
        
        // Add to countries list
        countries.append(customCountry)
        countries.sort { $0.name < $1.name } // Keep sorted
        
        print("🗺️ Added custom country: \(customCountry.name) at (\(coordinates.latitude), \(coordinates.longitude))")
        
        return customCountry
    }
    
    /// Get all locations (countries + states) by status
    func getAllLocations(by status: TravelStatus) -> [Any] {
        let visitedCountries = getCountries(by: status)
        let visitedStates = getStates(by: status)
        return visitedCountries + visitedStates
    }
    
    /// Get recent visits (last 10)
    func getRecentVisits() -> [Country] {
        return countries
            .filter { $0.travelStatus == .visited }
            .sorted { ($0.visitDate ?? Date.distantPast) > ($1.visitDate ?? Date.distantPast) }
            .prefix(10)
            .map { $0 }
    }
    
    /// Check and update achievements
    func checkAndUpdateAchievements() async {
        guard let userId = userId else { return }
        
        var updatedAchievements = achievements
        
        for i in 0..<updatedAchievements.count {
            let achievement = updatedAchievements[i]
            let newProgress = calculateAchievementProgress(for: achievement)
            
            if newProgress != achievement.progress {
                updatedAchievements[i].progress = newProgress
                
                // Check if achievement is newly unlocked
                if newProgress >= achievement.requirement && !achievement.isUnlocked {
                    updatedAchievements[i].isUnlocked = true
                    updatedAchievements[i].unlockedDate = Date()
                    
                    // Save to Firestore
                    await saveAchievementToFirestore(updatedAchievements[i])
                    
                    // Show achievement notification (could trigger UI notification)
                    NotificationCenter.default.post(name: .achievementUnlocked, object: updatedAchievements[i])
                }
            }
        }
        
        self.achievements = updatedAchievements
    }
    
    /// Calculate progress for a specific achievement
    private func calculateAchievementProgress(for achievement: Achievement) -> Int {
        switch achievement.id {
        case "first_visit", "explorer_5", "explorer_10", "explorer_25", "explorer_50":
            return getCountries(by: .visited).count
            
        case "europe_explorer":
            return getCountries(in: .europe).filter { $0.travelStatus == .visited }.count
            
        case "asia_explorer":
            return getCountries(in: .asia).filter { $0.travelStatus == .visited }.count
            
        case "americas_explorer":
            let northAmerica = getCountries(in: .northAmerica).filter { $0.travelStatus == .visited }.count
            let southAmerica = getCountries(in: .southAmerica).filter { $0.travelStatus == .visited }.count
            return northAmerica + southAmerica
            
        case "africa_explorer":
            return getCountries(in: .africa).filter { $0.travelStatus == .visited }.count
            
        case "world_10_percent", "world_25_percent", "world_50_percent":
            return getCountries(by: .visited).count
            
        case "wishlist_master":
            return getCountries(by: .wishlist).count
            
        case "verified_traveler":
            // For now, return visited count (can be enhanced with actual verification)
            return getCountries(by: .visited).count
            
        default:
            return 0
        }
    }
    
    /// Save achievement to Firestore
    private func saveAchievementToFirestore(_ achievement: Achievement) async {
        guard let userId = userId else { return }
        
        do {
            let achievementData: [String: Any] = [
                "isUnlocked": achievement.isUnlocked,
                "unlockedDate": achievement.unlockedDate != nil ? Timestamp(date: achievement.unlockedDate!) : FieldValue.delete(),
                "progress": achievement.progress,
                "lastUpdated": Timestamp(date: Date())
            ]
            
            try await db.collection("users").document(userId).collection("travelData").document("achievements").setData([
                achievement.id: achievementData
            ], merge: true)
            
        } catch {
            print("❌ TravelMapService: Error saving achievement - \(error)")
        }
    }
    
    /// Update countries from Firestore data
    private func updateCountriesFromFirestore(_ data: [String: Any]) async {
        for (countryId, countryData) in data {
            guard let countryInfo = countryData as? [String: Any],
                  let index = countries.firstIndex(where: { $0.id == countryId }) else { continue }
            
            if let statusString = countryInfo["status"] as? String,
               let status = TravelStatus(rawValue: statusString) {
                countries[index].travelStatus = status
            }
            
            if let visitDate = countryInfo["visitDate"] as? Timestamp {
                countries[index].visitDate = visitDate.dateValue()
            }
            
            if let notes = countryInfo["notes"] as? String {
                countries[index].notes = notes
            }
            
            if let photos = countryInfo["photos"] as? [String] {
                countries[index].photos = photos
            }
        }
    }

    /// Upload a travel photo for a specific country and return its download URL
    func uploadCountryPhoto(country: Country, imageData: Data) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "TravelMapService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let optimizedImageData = normalizeImageData(imageData)

        #if canImport(FirebaseStorage)
        do {
            let storageRef = Storage.storage()
                .reference()
                .child("travelPhotos")
                .child(userId)
                .child(country.id)
                .child("\(UUID().uuidString).jpg")
            
            _ = try await storageRef.putDataAsync(optimizedImageData)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        } catch {
            print("⚠️ TravelMapService: Firebase Storage upload failed, using local fallback - \(error.localizedDescription)")
            return try savePhotoLocally(countryId: country.id, userId: userId, imageData: optimizedImageData)
        }
        #else
        print("⚠️ TravelMapService: FirebaseStorage unavailable, using local fallback")
        return try savePhotoLocally(countryId: country.id, userId: userId, imageData: optimizedImageData)
        #endif
    }

    private func normalizeImageData(_ imageData: Data) -> Data {
        #if canImport(UIKit)
        if let image = UIImage(data: imageData),
           let jpegData = image.jpegData(compressionQuality: 0.82) {
            return jpegData
        }
        #endif
        return imageData
    }

    private func savePhotoLocally(countryId: String, userId: String, imageData: Data) throws -> String {
        let fileManager = FileManager.default
        let baseDirectory = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let countryDirectory = baseDirectory
            .appendingPathComponent("travelPhotos", isDirectory: true)
            .appendingPathComponent(userId, isDirectory: true)
            .appendingPathComponent(countryId, isDirectory: true)

        try fileManager.createDirectory(at: countryDirectory, withIntermediateDirectories: true)

        let fileURL = countryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try imageData.write(to: fileURL, options: .atomic)
        return fileURL.absoluteString
    }
    
    /// Update achievements from Firestore data
    private func updateAchievementsFromFirestore(_ data: [String: Any]) async {
        for (achievementId, achievementData) in data {
            guard let achievementInfo = achievementData as? [String: Any],
                  let index = achievements.firstIndex(where: { $0.id == achievementId }) else { continue }
            
            if let isUnlocked = achievementInfo["isUnlocked"] as? Bool {
                achievements[index].isUnlocked = isUnlocked
            }
            
            if let unlockedDate = achievementInfo["unlockedDate"] as? Timestamp {
                achievements[index].unlockedDate = unlockedDate.dateValue()
            }
            
            if let progress = achievementInfo["progress"] as? Int {
                achievements[index].progress = progress
            }
        }
    }
    
    /// Update travel statistics
    private func updateTravelStatistics() {
        travelStatistics.visitedCountries = getCountries(by: .visited).count
        travelStatistics.visitedStates = getStates(by: .visited).count
        travelStatistics.wishlistCountries = getCountries(by: .wishlist).count
        travelStatistics.wishlistStates = getStates(by: .wishlist).count
        travelStatistics.skippedCountries = getCountries(by: .skipped).count
        travelStatistics.skippedStates = getStates(by: .skipped).count
        travelStatistics.totalStates = states.count
        travelStatistics.recentVisits = getRecentVisits()
        travelStatistics.achievements = achievements.filter { $0.isUnlocked }
    }
    
    /// Reset to default state when user logs out
    private func resetToDefaultState() {
        countries = CountryData.allCountries
        travelStatistics = TravelStatistics()
        achievements = AchievementData.allAchievements
        errorMessage = nil
    }
    
    /// Export travel data for sharing
    func exportTravelData() -> [String: Any] {
        return [
            "visitedCountries": getCountries(by: .visited).map { $0.name },
            "wishlistCountries": getCountries(by: .wishlist).map { $0.name },
            "worldProgress": travelStatistics.worldProgress,
            "continentProgress": travelStatistics.continentProgress.mapValues { $0 },
            "achievements": achievements.filter { $0.isUnlocked }.map { $0.title },
            "exportDate": Date()
        ]
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}

// MARK: - Country Extensions
extension Country {
    /// Get the color for this country based on travel status
    var statusColor: Color {
        return travelStatus.color
    }
    
    /// Get the icon for this country based on travel status
    var statusIcon: String {
        return travelStatus.icon
    }
    
    /// Check if this country has been visited
    var isVisited: Bool {
        return travelStatus == .visited
    }
    
    /// Check if this country is on wishlist
    var isOnWishlist: Bool {
        return travelStatus == .wishlist
    }
    
    /// Get formatted visit date
    var formattedVisitDate: String? {
        guard let visitDate = visitDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: visitDate)
    }
}
