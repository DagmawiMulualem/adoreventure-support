//
//  AIIdeasService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import FirebaseFunctions
import FirebaseAuth

// ===== AI response models =====
struct AIIdeaResponse: Decodable { let ideas: [AIIdea] }

struct AIIdea: Decodable {
    let title: String
    let blurb: String
    let rating: Double
    let place: String
    let duration: String
    let priceRange: String
    let tags: [String]

    // Detail fields (optional)
    let address: String?
    let phone: String?
    let website: String?
    let bookingURL: String?
    let bestTime: String?
    let hours: [String]?

    enum CodingKeys: String, CodingKey {
        case title, blurb, rating, place, duration, tags
        case priceRange            // preferred
        case price                 // fallback 1
        case price_range           // fallback 2
        case address, phone, website, bookingURL, bestTime, hours
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        title   = try c.decode(String.self, forKey: .title)
        blurb   = try c.decode(String.self, forKey: .blurb)
        rating  = try c.decode(Double.self, forKey: .rating)
        place   = try c.decode(String.self, forKey: .place)
        duration = try c.decode(String.self, forKey: .duration)
        tags    = (try? c.decode([String].self, forKey: .tags)) ?? []

        // Price normalization
        let p1 = try? c.decode(String.self, forKey: .priceRange)
        let p2 = try? c.decode(String.self, forKey: .price)
        let p3 = try? c.decode(String.self, forKey: .price_range)
        let raw = (p1 ?? p2 ?? p3)?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ensure a friendly fallback if empty or missing
        priceRange = (raw?.isEmpty == false) ? raw! : "—"

        address = try? c.decode(String.self, forKey: .address)
        phone   = try? c.decode(String.self, forKey: .phone)
        website = try? c.decode(String.self, forKey: .website)
        bookingURL = try? c.decode(String.self, forKey: .bookingURL)
        bestTime = try? c.decode(String.self, forKey: .bestTime)
        hours    = try? c.decode([String].self, forKey: .hours)
    }
}

extension AIIdea {
    var asAVIdea: AVIdea {
        AVIdea(
            title: title,
            blurb: blurb,
            rating: rating,
            place: place,
            duration: duration,
            priceRange: priceRange,   // ← now always filled
            tags: tags,
            address: address,
            phone: phone,
            website: website,
            bookingURL: bookingURL,
            bestTime: bestTime,
            hours: hours
        )
    }
}

// ===== Main service =====
enum AIIdeasService {
    private static let maxRetries = 3
    private static let timeoutInterval: TimeInterval = 30.0

    
    static func fetchIdeas(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil
    ) async throws -> [AVIdea] {

        print("🤖 AI Service: Starting idea fetch for \(location) - \(category.rawValue)")
        
        // Check subscription status before making the call
        let subscriptionManager = SubscriptionManager.shared
        let canSearch = await subscriptionManager.canPerformSearch()
        
        if !canSearch {
            throw NSError(domain: "AIIdeasService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Search limit reached. Please upgrade to Premium for unlimited searches."])
        }
        
        print("🤖 AI Service: Calling AI directly...")
        
        // Prepare data
        let data: [String: Any] = [
            "location": location,
            "category": category.rawValue,
            "budgetHint": budgetHint ?? "",
            "timeHint": timeHint ?? "",
            "indoorOutdoor": indoorOutdoor ?? ""
        ]
        
        // Retry logic with exponential backoff
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🤖 AI Service: Attempt \(attempt)/\(maxRetries)")
                
                let result = try await withTimeout(seconds: timeoutInterval) {
                    let functions = Functions.functions()
                    return try await functions.httpsCallable("getIdeas").call(data)
                }
                
                print("🤖 AI Service: Firebase Function call successful")
                
                // Record the search after successful call
                await subscriptionManager.recordSearch()
                
                // Parse the result
                guard let resultData = result.data as? [String: Any],
                      let ideasData = resultData["ideas"] as? [[String: Any]] else {
                    throw NSError(domain: "AIIdeasService", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response format from Firebase Function"])
                }
                
                // Convert to AIIdea objects
                let ideas = try ideasData.map { ideaDict -> AIIdea in
                    let jsonData = try JSONSerialization.data(withJSONObject: ideaDict)
                    return try JSONDecoder().decode(AIIdea.self, from: jsonData)
                }
                
                let avIdeas = ideas.map { $0.asAVIdea }
                
                print("🤖 AI Service: Successfully parsed \(avIdeas.count) ideas")
                
                return avIdeas
                
            } catch {
                lastError = error
                print("🤖 AI Service: ❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    let delay = TimeInterval(attempt * 2) // Exponential backoff: 2s, 4s, 6s
                    print("🤖 AI Service: ⏳ Waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        print("🤖 AI Service: ❌ All \(maxRetries) attempts failed")
        throw lastError ?? NSError(domain: "AIIdeasService", code: -2,
                                   userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    

    
    /// Fetch more ideas (calls AI directly)
    static func fetchMoreIdeas(
        location: String,
        category: AVCategory,
        count: Int = 6,
        excludeIds: Set<UUID> = []
    ) async -> [AVIdea]? {
        // Call AI directly for fresh ideas
        do {
            let ideas = try await fetchIdeas(
                location: location,
                category: category
            )
            
            // Filter out excluded ideas
            let excludeIdStrings = Set(excludeIds.map { $0.uuidString })
            let filteredIdeas = ideas.filter { !excludeIdStrings.contains($0.id.uuidString) }
            
            return Array(filteredIdeas.prefix(count))
        } catch {
            print("🤖 AI Service: ❌ Error fetching more ideas: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper function for timeout
    private static func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "AIIdeasService", code: -4,
                              userInfo: [NSLocalizedDescriptionKey: "Request timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

extension AVCategory {
    var headerTitle: String {
        switch self {
        case .date: return "Date Ideas"
        case .birthday: return "Birthday Ideas"
        case .travel: return "Travel Activities"
        case .local: return "Local Activities"
        case .special: return "Special Events"
        case .group: return "Group Activities"
        }
    }
}

