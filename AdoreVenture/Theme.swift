//
//  Theme.swift
//  AdoreVenture
//

import SwiftUI
import Foundation

// MARK: - Category

enum AVCategory: String, CaseIterable, Identifiable {
    case date = "Date Ideas"
    case birthday = "Birthday Ideas"
    case travel = "Travel & Tourism"
    case local = "Local Activities"
    case special = "Special Events"
    case group = "Group Activities"

    var id: String { rawValue }


    var subtitle: String {
        switch self {
        case .date:     return "Romantic and fun date activities"
        case .birthday: return "Memorable birthday celebrations"
        case .travel:   return "Explore new destinations"
        case .local:    return "Things to do nearby"
        case .special:  return "Seasonal and holiday activities"
        case .group:    return "Fun with friends and family"
        }
    }

    var icon: String {
        switch self {
        case .date: return "heart.fill"
        case .birthday: return "gift.fill"
        case .travel: return "mappin.and.ellipse"
        case .local: return "figure.walk"
        case .special: return "calendar"
        case .group: return "person.3.fill"
        }
    }
}

// MARK: - Idea model (now includes detail fields)

struct AVIdea: Identifiable, Hashable, Codable {
    let id = UUID()

    // Core (list view)
    let title: String
    let blurb: String
    let rating: Double
    let place: String
    let duration: String
    let priceRange: String
    let tags: [String]

    // Detail fields (for Learn More)
    var address: String? = nil          // full street/city/state or neighborhood
    var phone: String? = nil            // e.g. "(202) 555-0199"
    var website: String? = nil          // https://...
    var bookingURL: String? = nil       // reservation link if any
    var bestTime: String? = nil         // e.g. "Golden hour (6–8 pm)"
    var hours: [String]? = nil          // e.g. ["Mon–Thu 10am–9pm", "Fri–Sat 10am–11pm", "Sun 10am–8pm"]

    // (Images removed from UI, keeping fields harmless if you add back later)
    var imageURL: String? = nil
    var imageCreditName: String? = nil
    var imageCreditLink: String? = nil
    
    // Cache-related fields
    var accessCount: Int? = nil
    var lastAccessed: Date? = nil
}

// MARK: - AVIdea Extensions

extension AVIdea {
    static func from(dictionary: [String: Any]) -> AVIdea? {
        guard let title = dictionary["title"] as? String,
              let blurb = dictionary["blurb"] as? String,
              let rating = dictionary["rating"] as? Double,
              let place = dictionary["place"] as? String,
              let duration = dictionary["duration"] as? String,
              let priceRange = dictionary["priceRange"] as? String,
              let tags = dictionary["tags"] as? [String] else {
            return nil
        }
        
        var idea = AVIdea(
            title: title,
            blurb: blurb,
            rating: rating,
            place: place,
            duration: duration,
            priceRange: priceRange,
            tags: tags
        )
        
        // Optional fields
        idea.address = dictionary["address"] as? String
        idea.phone = dictionary["phone"] as? String
        idea.website = dictionary["website"] as? String
        idea.bookingURL = dictionary["bookingURL"] as? String
        idea.bestTime = dictionary["bestTime"] as? String
        idea.hours = dictionary["hours"] as? [String]
        idea.imageURL = dictionary["imageURL"] as? String
        idea.imageCreditName = dictionary["imageCreditName"] as? String
        idea.imageCreditLink = dictionary["imageCreditLink"] as? String
        idea.accessCount = dictionary["accessCount"] as? Int
        idea.lastAccessed = dictionary["lastAccessed"] as? Date
        
        return idea
    }
}

// MARK: - Theme

enum AVTheme {
    static let gradient = LinearGradient(
        colors: [ Color.orange.opacity(0.95), Color.pink.opacity(0.92) ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accent = Color.orange
    static let surface = Color(.systemBackground)
    static let card = Color(.secondarySystemBackground)
}

struct AVTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption).fontWeight(.medium)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(AVTheme.card)
            .clipShape(Capsule())
    }
}

extension View {
    func avCard() -> some View {
        self
            .background(AVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
            )
    }
}
