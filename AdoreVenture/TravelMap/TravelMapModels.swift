//
//  TravelMapModels.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import SwiftUI

// MARK: - Travel Status Enum
enum TravelStatus: String, CaseIterable, Codable {
    case visited = "visited"
    case wishlist = "wishlist"
    case skipped = "skipped"
    case untouched = "untouched"
    
    var displayName: String {
        switch self {
        case .visited: return "Visited"
        case .wishlist: return "Wishlist"
        case .skipped: return "Skipped"
        case .untouched: return "Not Visited"
        }
    }
    
    var color: Color {
        switch self {
        case .visited: return .green
        case .wishlist: return .blue
        case .skipped: return .red
        case .untouched: return .gray.opacity(0.3)
        }
    }
    
    var icon: String {
        switch self {
        case .visited: return "checkmark.circle.fill"
        case .wishlist: return "heart.fill"
        case .skipped: return "xmark.circle.fill"
        case .untouched: return "circle"
        }
    }
}

// MARK: - Country Model
struct Country: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let code: String // ISO 3166-1 alpha-2
    let continent: Continent
    let coordinates: CountryCoordinates
    let population: Int?
    let area: Double? // in km²
    let states: [TravelState]? // States/provinces within the country
    
    // Travel-specific properties
    var travelStatus: TravelStatus = .untouched
    var visitDate: Date?
    var notes: String?
    var photos: [String] = [] // URLs to photos
    
    init(id: String, name: String, code: String, continent: Continent, coordinates: CountryCoordinates, population: Int? = nil, area: Double? = nil, states: [TravelState]? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.continent = continent
        self.coordinates = coordinates
        self.population = population
        self.area = area
        self.states = states
    }
}

// MARK: - State/Province Model
struct TravelState: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let countryCode: String
    let coordinates: CountryCoordinates
    let population: Int?
    let area: Double?
    
    // Travel-specific properties
    var travelStatus: TravelStatus = .untouched
    var visitDate: Date?
    var notes: String?
    var photos: [String] = []
    
    init(id: String, name: String, countryCode: String, coordinates: CountryCoordinates, population: Int? = nil, area: Double? = nil) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.coordinates = coordinates
        self.population = population
        self.area = area
    }
}

// MARK: - Continent Enum
enum Continent: String, CaseIterable, Codable {
    case africa = "Africa"
    case antarctica = "Antarctica"
    case asia = "Asia"
    case europe = "Europe"
    case northAmerica = "North America"
    case oceania = "Oceania"
    case southAmerica = "South America"
    
    var displayName: String {
        return rawValue
    }
    
    var color: Color {
        switch self {
        case .africa: return .orange
        case .antarctica: return .white
        case .asia: return .red
        case .europe: return .blue
        case .northAmerica: return .green
        case .oceania: return .purple
        case .southAmerica: return .yellow
        }
    }
    
    var icon: String {
        switch self {
        case .africa: return "globe"
        case .antarctica: return "snowflake"
        case .asia: return "globe.asia.australia"
        case .europe: return "globe.europe.africa"
        case .northAmerica: return "globe.americas"
        case .oceania: return "globe"
        case .southAmerica: return "globe.americas.fill"
        }
    }
}

// MARK: - Country Coordinates
struct CountryCoordinates: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    // For map positioning and pin placement
    var normalizedX: Double {
        // Convert longitude to 0-1 range for map texture
        return (longitude + 180) / 360
    }
    
    var normalizedY: Double {
        // Convert latitude to 0-1 range for map texture (inverted for map coordinates)
        return (90 - latitude) / 180
    }
}

// MARK: - Travel Pin
struct TravelPin: Identifiable, Codable {
    let id = UUID()
    let countryId: String
    let visitDate: Date
    let notes: String?
    let photos: [String]
    let isVerified: Bool // For future GPS/photo verification
    
    init(countryId: String, visitDate: Date = Date(), notes: String? = nil, photos: [String] = [], isVerified: Bool = false) {
        self.countryId = countryId
        self.visitDate = visitDate
        self.notes = notes
        self.photos = photos
        self.isVerified = isVerified
    }
}

// MARK: - Achievement Model
struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let requirement: Int // Number needed to unlock
    let reward: String? // Optional reward description
    var isUnlocked: Bool = false
    var unlockedDate: Date?
    var progress: Int = 0
    
    init(id: String, title: String, description: String, icon: String, category: AchievementCategory, requirement: Int, reward: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.category = category
        self.requirement = requirement
        self.reward = reward
    }
}

// MARK: - Achievement Category
enum AchievementCategory: String, CaseIterable, Codable {
    case explorer = "Explorer"
    case continent = "Continent"
    case milestone = "Milestone"
    case special = "Special"
    
    var displayName: String {
        return rawValue
    }
    
    var color: Color {
        switch self {
        case .explorer: return .green
        case .continent: return .blue
        case .milestone: return .purple
        case .special: return .orange
        }
    }
}

// MARK: - Travel Statistics
struct TravelStatistics: Codable {
    var totalCountries: Int = 195 // Total countries in the world
    var totalStates: Int = 0 // Total states/provinces
    var visitedCountries: Int = 0
    var visitedStates: Int = 0
    var wishlistCountries: Int = 0
    var wishlistStates: Int = 0
    var skippedCountries: Int = 0
    var skippedStates: Int = 0
    
    var totalLocations: Int {
        return totalCountries + totalStates
    }
    
    var visitedLocations: Int {
        return visitedCountries + visitedStates
    }
    
    var worldProgress: Double {
        guard totalLocations > 0 else { return 0 }
        let p = Double(visitedLocations) / Double(totalLocations)
        return p.safeProgressValue
    }
    
    var continentProgress: [Continent: Double] {
        var progress: [Continent: Double] = [:]
        
        for continent in Continent.allCases {
            let continentCountries = CountryData.allCountries.filter { $0.continent == continent }
            let visitedInContinent = continentCountries.filter { $0.travelStatus == .visited }.count
            let raw = continentCountries.isEmpty ? 0 : Double(visitedInContinent) / Double(continentCountries.count)
            progress[continent] = raw.safeProgressValue
        }
        
        return progress
    }
    
    var recentVisits: [Country] = []
    var achievements: [Achievement] = []
}

// MARK: - Country Data (Static data for all countries)
struct CountryData {
    static let allCountries: [Country] = [
        // Africa
        Country(id: "DZ", name: "Algeria", code: "DZ", continent: .africa, coordinates: CountryCoordinates(latitude: 28.0339, longitude: 1.6596)),
        Country(id: "AO", name: "Angola", code: "AO", continent: .africa, coordinates: CountryCoordinates(latitude: -11.2027, longitude: 17.8739)),
        Country(id: "BW", name: "Botswana", code: "BW", continent: .africa, coordinates: CountryCoordinates(latitude: -22.3285, longitude: 24.6849)),
        Country(id: "EG", name: "Egypt", code: "EG", continent: .africa, coordinates: CountryCoordinates(latitude: 26.0975, longitude: 30.0444)),
        Country(id: "ET", name: "Ethiopia", code: "ET", continent: .africa, coordinates: CountryCoordinates(latitude: 9.1450, longitude: 40.4897)),
        Country(id: "GH", name: "Ghana", code: "GH", continent: .africa, coordinates: CountryCoordinates(latitude: 7.9465, longitude: -1.0232)),
        Country(id: "KE", name: "Kenya", code: "KE", continent: .africa, coordinates: CountryCoordinates(latitude: -0.0236, longitude: 37.9062)),
        Country(id: "MA", name: "Morocco", code: "MA", continent: .africa, coordinates: CountryCoordinates(latitude: 31.6295, longitude: -7.9811)),
        Country(id: "NG", name: "Nigeria", code: "NG", continent: .africa, coordinates: CountryCoordinates(latitude: 9.0820, longitude: 8.6753)),
        Country(id: "ZA", name: "South Africa", code: "ZA", continent: .africa, coordinates: CountryCoordinates(latitude: -30.5595, longitude: 22.9375)),
        Country(id: "TZ", name: "Tanzania", code: "TZ", continent: .africa, coordinates: CountryCoordinates(latitude: -6.3690, longitude: 34.8888)),
        Country(id: "TN", name: "Tunisia", code: "TN", continent: .africa, coordinates: CountryCoordinates(latitude: 33.8869, longitude: 9.5375)),
        Country(id: "SO", name: "Somalia", code: "SO", continent: .africa, coordinates: CountryCoordinates(latitude: 5.1521, longitude: 46.1996)),
        
        // Asia
        Country(id: "CN", name: "China", code: "CN", continent: .asia, coordinates: CountryCoordinates(latitude: 35.8617, longitude: 104.1954)),
        Country(id: "IN", name: "India", code: "IN", continent: .asia, coordinates: CountryCoordinates(latitude: 20.5937, longitude: 78.9629)),
        Country(id: "ID", name: "Indonesia", code: "ID", continent: .asia, coordinates: CountryCoordinates(latitude: -0.7893, longitude: 113.9213)),
        Country(id: "JP", name: "Japan", code: "JP", continent: .asia, coordinates: CountryCoordinates(latitude: 36.2048, longitude: 138.2529)),
        Country(id: "KR", name: "South Korea", code: "KR", continent: .asia, coordinates: CountryCoordinates(latitude: 35.9078, longitude: 127.7669)),
        Country(id: "MY", name: "Malaysia", code: "MY", continent: .asia, coordinates: CountryCoordinates(latitude: 4.2105, longitude: 101.9758)),
        Country(id: "PH", name: "Philippines", code: "PH", continent: .asia, coordinates: CountryCoordinates(latitude: 12.8797, longitude: 121.7740)),
        Country(id: "SG", name: "Singapore", code: "SG", continent: .asia, coordinates: CountryCoordinates(latitude: 1.3521, longitude: 103.8198)),
        Country(id: "TH", name: "Thailand", code: "TH", continent: .asia, coordinates: CountryCoordinates(latitude: 15.8700, longitude: 100.9925)),
        Country(id: "VN", name: "Vietnam", code: "VN", continent: .asia, coordinates: CountryCoordinates(latitude: 14.0583, longitude: 108.2772)),
        
        // Europe
        Country(id: "AT", name: "Austria", code: "AT", continent: .europe, coordinates: CountryCoordinates(latitude: 47.5162, longitude: 14.5501)),
        Country(id: "BE", name: "Belgium", code: "BE", continent: .europe, coordinates: CountryCoordinates(latitude: 50.5039, longitude: 4.4699)),
        Country(id: "FR", name: "France", code: "FR", continent: .europe, coordinates: CountryCoordinates(latitude: 46.2276, longitude: 2.2137)),
        Country(id: "DE", name: "Germany", code: "DE", continent: .europe, coordinates: CountryCoordinates(latitude: 51.1657, longitude: 10.4515)),
        Country(id: "IT", name: "Italy", code: "IT", continent: .europe, coordinates: CountryCoordinates(latitude: 41.8719, longitude: 12.5674)),
        Country(id: "NL", name: "Netherlands", code: "NL", continent: .europe, coordinates: CountryCoordinates(latitude: 52.1326, longitude: 5.2913)),
        Country(id: "ES", name: "Spain", code: "ES", continent: .europe, coordinates: CountryCoordinates(latitude: 40.4637, longitude: -3.7492)),
        Country(id: "CH", name: "Switzerland", code: "CH", continent: .europe, coordinates: CountryCoordinates(latitude: 46.8182, longitude: 8.2275)),
        Country(id: "GB", name: "United Kingdom", code: "GB", continent: .europe, coordinates: CountryCoordinates(latitude: 55.3781, longitude: -3.4360)),
        
        // North America
        Country(id: "CA", name: "Canada", code: "CA", continent: .northAmerica, coordinates: CountryCoordinates(latitude: 56.1304, longitude: -106.3468)),
        Country(id: "MX", name: "Mexico", code: "MX", continent: .northAmerica, coordinates: CountryCoordinates(latitude: 23.6345, longitude: -102.5528)),
        Country(id: "US", name: "United States", code: "US", continent: .northAmerica, coordinates: CountryCoordinates(latitude: 37.0902, longitude: -95.7129), states: [
            TravelState(id: "CA", name: "California", countryCode: "US", coordinates: CountryCoordinates(latitude: 36.7783, longitude: -119.4179)),
            TravelState(id: "NY", name: "New York", countryCode: "US", coordinates: CountryCoordinates(latitude: 42.1657, longitude: -74.9481)),
            TravelState(id: "TX", name: "Texas", countryCode: "US", coordinates: CountryCoordinates(latitude: 31.9686, longitude: -99.9018)),
            TravelState(id: "FL", name: "Florida", countryCode: "US", coordinates: CountryCoordinates(latitude: 27.7663, longitude: -82.6404)),
            TravelState(id: "IL", name: "Illinois", countryCode: "US", coordinates: CountryCoordinates(latitude: 40.3363, longitude: -89.0022)),
            TravelState(id: "PA", name: "Pennsylvania", countryCode: "US", coordinates: CountryCoordinates(latitude: 41.2033, longitude: -77.1945)),
            TravelState(id: "OH", name: "Ohio", countryCode: "US", coordinates: CountryCoordinates(latitude: 40.3888, longitude: -82.7649)),
            TravelState(id: "GA", name: "Georgia", countryCode: "US", coordinates: CountryCoordinates(latitude: 33.0406, longitude: -83.6431)),
            TravelState(id: "NC", name: "North Carolina", countryCode: "US", coordinates: CountryCoordinates(latitude: 35.6300, longitude: -79.8064)),
            TravelState(id: "MI", name: "Michigan", countryCode: "US", coordinates: CountryCoordinates(latitude: 43.3266, longitude: -84.5361))
        ]),
        
        // South America
        Country(id: "AR", name: "Argentina", code: "AR", continent: .southAmerica, coordinates: CountryCoordinates(latitude: -38.4161, longitude: -63.6167)),
        Country(id: "BR", name: "Brazil", code: "BR", continent: .southAmerica, coordinates: CountryCoordinates(latitude: -14.2350, longitude: -51.9253)),
        Country(id: "CL", name: "Chile", code: "CL", continent: .southAmerica, coordinates: CountryCoordinates(latitude: -35.6751, longitude: -71.5430)),
        Country(id: "CO", name: "Colombia", code: "CO", continent: .southAmerica, coordinates: CountryCoordinates(latitude: 4.5709, longitude: -74.2973)),
        Country(id: "PE", name: "Peru", code: "PE", continent: .southAmerica, coordinates: CountryCoordinates(latitude: -9.1900, longitude: -75.0152)),
        
        // Oceania
        Country(id: "AU", name: "Australia", code: "AU", continent: .oceania, coordinates: CountryCoordinates(latitude: -25.2744, longitude: 133.7751)),
        Country(id: "NZ", name: "New Zealand", code: "NZ", continent: .oceania, coordinates: CountryCoordinates(latitude: -40.9006, longitude: 174.8860)),
        Country(id: "FJ", name: "Fiji", code: "FJ", continent: .oceania, coordinates: CountryCoordinates(latitude: -16.5785, longitude: 179.4144))
    ]
    
    static func country(by code: String) -> Country? {
        return allCountries.first { $0.code == code }
    }
    
    static func countries(in continent: Continent) -> [Country] {
        return allCountries.filter { $0.continent == continent }
    }
    
    static func allStates() -> [TravelState] {
        return allCountries.compactMap { $0.states }.flatMap { $0 }
    }
    
    static func state(by id: String) -> TravelState? {
        return allStates().first { $0.id == id }
    }
}

// MARK: - Achievement Definitions
struct AchievementData {
    static let allAchievements: [Achievement] = [
        // Explorer Achievements
        Achievement(id: "first_visit", title: "First Steps", description: "Visit your first country", icon: "figure.walk", category: .explorer, requirement: 1),
        Achievement(id: "explorer_5", title: "Explorer", description: "Visit 5 countries", icon: "map", category: .explorer, requirement: 5),
        Achievement(id: "explorer_10", title: "Adventurer", description: "Visit 10 countries", icon: "backpack", category: .explorer, requirement: 10),
        Achievement(id: "explorer_25", title: "Globe Trotter", description: "Visit 25 countries", icon: "globe", category: .explorer, requirement: 25),
        Achievement(id: "explorer_50", title: "World Traveler", description: "Visit 50 countries", icon: "airplane", category: .explorer, requirement: 50),
        
        // Continent Achievements
        Achievement(id: "europe_explorer", title: "Europe Explorer", description: "Visit 10 European countries", icon: "globe.europe.africa", category: .continent, requirement: 10),
        Achievement(id: "asia_explorer", title: "Asia Explorer", description: "Visit 10 Asian countries", icon: "globe.asia.australia", category: .continent, requirement: 10),
        Achievement(id: "americas_explorer", title: "Americas Explorer", description: "Visit 10 countries in the Americas", icon: "globe.americas", category: .continent, requirement: 10),
        Achievement(id: "africa_explorer", title: "Africa Explorer", description: "Visit 10 African countries", icon: "globe.africa", category: .continent, requirement: 10),
        
        // Milestone Achievements
        Achievement(id: "world_10_percent", title: "World Explorer", description: "Visit 10% of the world", icon: "percent", category: .milestone, requirement: 20),
        Achievement(id: "world_25_percent", title: "Global Citizen", description: "Visit 25% of the world", icon: "star.circle", category: .milestone, requirement: 49),
        Achievement(id: "world_50_percent", title: "World Conqueror", description: "Visit 50% of the world", icon: "crown", category: .milestone, requirement: 98),
        
        // Special Achievements
        Achievement(id: "wishlist_master", title: "Dreamer", description: "Add 20 countries to your wishlist", icon: "heart.circle", category: .special, requirement: 20),
        Achievement(id: "verified_traveler", title: "Verified Traveler", description: "Get 10 verified visits", icon: "checkmark.seal", category: .special, requirement: 10)
    ]
}

// MARK: - NaN-safe progress for CoreGraphics (set CG_NUMERICS_SHOW_BACKTRACE=1 to trace sources)
extension Double {
    /// Clamps to 0...1 and replaces NaN/Infinity with 0 to avoid CoreGraphics NaN crashes.
    var safeProgressValue: Double {
        avClampedUnitInterval
    }
}
