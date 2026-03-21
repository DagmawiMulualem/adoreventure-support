//
//  AIIdeasService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import FirebaseFunctions
#if canImport(UIKit)
import UIKit
#endif

/// One in-flight `getSingleIdea` at a time avoids GTMSessionFetcher "was already running" when retries or other code overlap.
private actor GetSingleIdeaSerialization {
    static let shared = GetSingleIdeaSerialization()
    func callAndGetData(_ payload: [String: Any]) async throws -> Any? {
        let functions = Functions.functions()
        let result = try await functions.httpsCallable("getSingleIdea").call(payload)
        try? await Task.sleep(nanoseconds: 120_000_000)
        return result.data
    }
}

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
        let rawRating = try c.decode(Double.self, forKey: .rating)
        rating = rawRating.avSanitizedStarRating
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
@MainActor
class AIIdeasService: ObservableObject {
    static let shared = AIIdeasService()
    
    @Published var isLoading = false
    @Published var ideas: [AVIdea] = []
    @Published var error: String?
    
    private let cacheService = IdeaCacheService.shared
    private let firebaseManager = FirebaseManager.shared
    private let subscriptionManager = SubscriptionManager.shared
    
    private let maxRetries = 3
    /// Batch `getIdeas` via Cloud Function can wait on Render + OpenAI (cold start often 45–60s).
    private let timeoutInterval: TimeInterval = 85.0
    /// Must exceed Firebase→Render HTTP wait (60s) + small overhead, or client times out with code 4 while
    /// the server still succeeds (seen ~49s for single idea on cold start).
    private let singleIdeaTimeoutInterval: TimeInterval = 75.0
    
    // Ensure we never run more than one network AI call at a time across the app
    private static var isFetching = false

    
    func fetchIdeas(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        userQuery: String? = nil,
        skipCache: Bool = false,
        previousTitles: [String] = []
    ) async throws -> [AVIdea] {

        print("🤖 AI Service: Starting idea fetch for \(location) - \(category.rawValue)")
        
        // Check subscription status before making the call
        let canSearch = await subscriptionManager.canPerformSearch()
        
        if !canSearch {
            throw NSError(domain: "AIIdeasService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Search limit reached. Please upgrade to Premium for unlimited searches."])
        }
        
        // Fast validation to avoid slow geocoding
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValidLocation = validateLocationFast(trimmedLocation)
        
        if !isValidLocation {
            let error = NSError(domain: "AIIdeasService", code: -8,
                              userInfo: [NSLocalizedDescriptionKey: "Please enter a country or city name, not a specific address. For example: 'New York' or 'France' instead of '123 Main Street'."])
            print("🤖 AI Service: ❌ Invalid location type: \(trimmedLocation)")
            throw error
        }
        
        // Cache-first: if we already have ideas, return them instantly (unless explicitly skipped or asking for different ideas via previousTitles)
        if !skipCache && previousTitles.isEmpty {
            if let cached = await cacheService.getCachedIdeasOnly(
                location: location,
                category: category,
                budgetHint: budgetHint,
                timeHint: timeHint,
                indoorOutdoor: indoorOutdoor
            ) {
                print("🤖 AI Service: Returning \(cached.count) cached ideas from IdeaCacheService")
                return cached
            }
        }
        
        print("🤖 AI Service: Calling AI directly...")
        
        // Prepare data (previousTitles so backend returns different ideas for "More Ideas")
        let currentModel = subscriptionManager.currentModel
        let effectiveTimeHint = normalizedTimeHint(for: category, requestedTimeHint: timeHint)
        var data: [String: Any] = [
            "location": location.trimmingCharacters(in: .whitespacesAndNewlines),
            "category": category.rawValue,
            "budgetHint": budgetHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "timeHint": effectiveTimeHint,
            "indoorOutdoor": indoorOutdoor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "userQuery": userQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "model": currentModel.rawValue
        ]
        if !previousTitles.isEmpty {
            data["previous_titles"] = Array(previousTitles.prefix(15))
        }
        
        // Validate data before sending
        guard let locationString = data["location"] as? String, !locationString.isEmpty else {
            let error = NSError(domain: "AIIdeasService", code: -5,
                               userInfo: [NSLocalizedDescriptionKey: "Location cannot be empty"])
            
            print("🤖 AI Service: ❌ Search failed for '\(location) \(category.rawValue)': \(error.localizedDescription)")
            
            throw error
        }
        
        print("🤖 AI Service: Sending data to Firebase Function: \(data)")
        
        // Ensure only one network AI call runs at a time (global lock)
        if Self.isFetching {
            print("🚫 AI already fetching — blocked duplicate call")
            if let cached = await cacheService.getCachedIdeasOnly(
                location: location,
                category: category,
                budgetHint: budgetHint,
                timeHint: timeHint,
                indoorOutdoor: indoorOutdoor
            ) {
                return cached
            }
            throw NSError(domain: "AIIdeasService", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "A search is already in progress. Please wait a moment and try again."])
        }
        
        Self.isFetching = true
        defer { Self.isFetching = false }
        
        // Client-side timeout guard (in addition to Cloud Function timeout)
        var finalIdeas: [AVIdea]?
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Actual AI call
            group.addTask { [self] in
                let ideas = try await self.performNetworkFetchIdeas(
                    location: location,
                    category: category,
                    data: data
                )
                finalIdeas = ideas
            }
            
            // Timeout task — must match `timeoutInterval` (Render + OpenAI can be slow on cold start)
            group.addTask { [timeoutInterval] in
                try await Task.sleep(nanoseconds: UInt64(timeoutInterval * 1_000_000_000))
                throw URLError(.timedOut)
            }
            
            // Wait for the first task to complete or throw
            _ = try await group.next()
            group.cancelAll()
        }
        
        if let finalIdeas {
            return finalIdeas
        }
        
        throw NSError(domain: "AIIdeasService", code: -11,
                      userInfo: [NSLocalizedDescriptionKey: "AI request cancelled or timed out. Please try again."])
    }
    
    /// Fetch ideas one at a time; call onIdea for each as it arrives (true streaming).
    func fetchIdeasStreaming(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        /// Called immediately before batch fallback re-streams ideas — clear any partial single-idea cards so UI stays 3 items, not 2+3.
        onBatchFallbackReset: (@Sendable () async -> Void)? = nil,
        onIdea: @escaping (AVIdea) async -> Void
    ) async throws -> [AVIdea] {
        let pipelineStartedAt = Date()
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📡 STREAM PIPELINE START | \(streamContext(location: trimmedLocation, category: category))")
        let canSearch = await subscriptionManager.canPerformSearch()
        if !canSearch {
            throw NSError(domain: "AIIdeasService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Search limit reached. Please upgrade to Premium for unlimited searches."])
        }
        if !validateLocationFast(trimmedLocation) {
            throw NSError(domain: "AIIdeasService", code: -8,
                          userInfo: [NSLocalizedDescriptionKey: "Please enter a country or city name."])
        }
        if Self.isFetching {
            throw NSError(domain: "AIIdeasService", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "A search is already in progress. Please wait."])
        }
        Self.isFetching = true
        defer { Self.isFetching = false }
        
        let model = subscriptionManager.currentModel.rawValue
        let effectiveTimeHint = normalizedTimeHint(for: category, requestedTimeHint: timeHint)
        var allIdeas: [AVIdea] = []
        var previousTitles: [String] = []
        let total = 3

        do {
            for index in 1...total {
                let singleStartedAt = Date()
                let idea = try await performNetworkFetchSingleIdeaWithRetry(
                    location: trimmedLocation,
                    category: category,
                    index: index,
                    total: total,
                    previousTitles: previousTitles,
                    budgetHint: budgetHint,
                    timeHint: effectiveTimeHint,
                    indoorOutdoor: indoorOutdoor,
                    model: model
                )
                allIdeas.append(idea)
                previousTitles.append(idea.title)
                await onIdea(idea)
                logStageDuration(
                    stage: "single_idea_completed_\(index)_of_\(total)",
                    startedAt: singleStartedAt,
                    location: trimmedLocation,
                    category: category
                )
            }
        } catch {
            // Task cancellation (navigation, .task replaced) — do not run batch fallback or we double-append UI + burn time/credits oddly.
            if error is CancellationError {
                print("🤖 AI Service: Streaming cancelled — not falling back to batch (\(error.localizedDescription))")
                throw error
            }
            print("🤖 AI Service: Streaming single-idea path failed, falling back to batch stream: \(error.localizedDescription)")
            await onBatchFallbackReset?()
            let fallback = try await streamFromBatchFallback(
                location: trimmedLocation,
                category: category,
                budgetHint: budgetHint,
                timeHint: effectiveTimeHint,
                indoorOutdoor: indoorOutdoor,
                model: model,
                onIdea: onIdea
            )
            logStageDuration(stage: "stream_pipeline_fallback_complete", startedAt: pipelineStartedAt, location: trimmedLocation, category: category)
            return fallback
        }
        
        await recordSearchUsage(location: trimmedLocation, category: category)
        await cacheIdeas(ideas: allIdeas, location: trimmedLocation, category: category)
        print("🤖 AI Service: ✅ Streaming done, generated and cached \(allIdeas.count) ideas")
        logStageDuration(stage: "stream_pipeline_success", startedAt: pipelineStartedAt, location: trimmedLocation, category: category)
        return allIdeas
    }
    
    /// Get more ideas (continues from where user left off)
    func getMoreIdeas(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        excludeIds: Set<String> = []
    ) async -> [AVIdea]? {
        // Call AI directly for fresh ideas
        do {
            let ideas = try await fetchIdeas(
                location: location,
                category: category
            )
            
            // Filter out excluded ideas (IDs are now Strings)
            let filteredIdeas = ideas.filter { !excludeIds.contains($0.id) }
            
            return Array(filteredIdeas.prefix(3))
        } catch {
            print("🤖 AI Service: ❌ Error fetching more ideas: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Core network logic to call the Firebase Function and parse the result.
    private func performNetworkFetchIdeas(
        location: String,
        category: AVCategory,
        data: [String: Any]
    ) async throws -> [AVIdea] {
        var lastError: Error?
        
        // Retry logic with exponential backoff (Firebase Functions only)
        for attempt in 1...maxRetries {
            do {
                print("🤖 AI Service: Attempt \(attempt)/\(maxRetries)")
                
                let functions = Functions.functions()
                let result = try await functions.httpsCallable("getIdeas").call(data)
                
                guard let resultData = result.data as? [String: Any],
                      let ideasData = resultData["ideas"] as? [[String: Any]] else {
                    throw NSError(domain: "AIIdeasService", code: -6,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response format from Firebase Function"])
                }
                
                print("🤖 AI Service: Raw response data: \(resultData)")
                print("🤖 AI Service: Ideas data count: \(ideasData.count)")
                
                // Check if we got any ideas
                guard !ideasData.isEmpty else {
                    print("🤖 AI Service: ❌ No ideas returned from AI service")
                    throw NSError(domain: "AIIdeasService", code: -7,
                                  userInfo: [NSLocalizedDescriptionKey: "No ideas found for this location and category. Please try a different search."])
                }
                
                // Convert to AIIdea objects
                let ideas = try ideasData.map { ideaDict -> AIIdea in
                    let jsonData = try JSONSerialization.data(withJSONObject: ideaDict)
                    return try JSONDecoder().decode(AIIdea.self, from: jsonData)
                }
                
                let avIdeas = ideas.map { $0.asAVIdea }
                
                print("🤖 AI Service: Successfully parsed \(avIdeas.count) ideas")
                
                // Record search usage (this will handle credit deduction)
                await recordSearchUsage(location: location, category: category)
                
                // Cache the ideas using the correct method
                await cacheIdeas(ideas: avIdeas, location: location, category: category)
                
                print("🤖 AI Service: ✅ Successfully generated and cached \(avIdeas.count) ideas")
                
                return avIdeas
                
            } catch {
                lastError = error
                let err = error as NSError
                print("🤖 AI Service: ❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                print("🤖 AI Service: Error domain: \(err.domain)")
                print("🤖 AI Service: Error code: \(err.code)")
                logCallableNSError(err, label: "getIdeas")
                
                let isRetryable = attempt < maxRetries && (
                    err.domain == "com.firebase.functions" && (err.code == 13 || err.code == 4) || // INTERNAL or deadline-exceeded
                    err.domain == NSURLErrorDomain && err.code == -1001 // timeout
                )
                if isRetryable {
                    let delay = TimeInterval(attempt * 2)
                    print("🤖 AI Service: Retryable error (code \(err.code)), waiting \(delay)s before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else if attempt < maxRetries {
                    let delay = TimeInterval(attempt * 2)
                    print("🤖 AI Service: Waiting \(delay)s before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        print("🤖 AI Service: ❌ All \(maxRetries) attempts failed in performNetworkFetchIdeas")
        if let lastError = lastError {
            print("🤖 AI Service: Last error: \(lastError.localizedDescription)")
            print("🤖 AI Service: Last error domain: \((lastError as NSError).domain)")
            print("🤖 AI Service: Last error code: \((lastError as NSError).code)")
        }
        
        throw lastError ?? NSError(domain: "AIIdeasService", code: -8,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to generate ideas after multiple attempts. Please try again."])
    }
    
    /// Fetch a single idea (for streaming: one card at a time).
    private func performNetworkFetchSingleIdeaWithRetry(
        location: String,
        category: AVCategory,
        index: Int,
        total: Int,
        previousTitles: [String],
        budgetHint: String?,
        timeHint: String?,
        indoorOutdoor: String?,
        model: String
    ) async throws -> AVIdea {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                print("🤖 AI Service: Single idea attempt \(attempt)/\(maxRetries) for item \(index)/\(total)")
                return try await performNetworkFetchSingleIdeaWithTimeout(
                    location: location,
                    category: category,
                    index: index,
                    total: total,
                    previousTitles: previousTitles,
                    budgetHint: budgetHint,
                    timeHint: timeHint,
                    indoorOutdoor: indoorOutdoor,
                    model: model
                )
            } catch {
                lastError = error
                if error is CancellationError {
                    print("🤖 AI Service: Single idea cancelled — not retrying")
                    throw error
                }
                let nsError = error as NSError
                print("🤖 AI Service: ❌ Single idea attempt \(attempt) failed: \(error.localizedDescription)")
                print("🤖 AI Service: Single idea error domain/code: \(nsError.domain)/\(nsError.code)")
                logCallableNSError(nsError, label: "getSingleIdea")
                let shouldRetry = attempt < maxRetries && isRetryableNetworkError(error)
                if shouldRetry {
                    // Longer backoff for INTERNAL (13) — Render/backend cold starts
                    let base = (nsError.domain == "com.firebase.functions" && nsError.code == 13) ? 1.5 : 1.0
                    var delayNs = UInt64(Double(attempt) * base * 1_000_000_000)
                    // Let the previous HTTPS session finish tearing down after a local timeout / cancel.
                    if nsError.domain == NSURLErrorDomain && nsError.code == -1001 {
                        delayNs += 500_000_000
                    }
                    try? await Task.sleep(nanoseconds: delayNs)
                }
            }
        }

        throw lastError ?? NSError(
            domain: "AIIdeasService",
            code: -12,
            userInfo: [NSLocalizedDescriptionKey: "Failed to fetch streamed idea after retries."]
        )
    }

    private func performNetworkFetchSingleIdeaWithTimeout(
        location: String,
        category: AVCategory,
        index: Int,
        total: Int,
        previousTitles: [String],
        budgetHint: String?,
        timeHint: String?,
        indoorOutdoor: String?,
        model: String
    ) async throws -> AVIdea {
        try await withThrowingTaskGroup(of: AVIdea.self) { group in
            group.addTask { [self] in
                try await self.performNetworkFetchSingleIdea(
                    location: location,
                    category: category,
                    index: index,
                    total: total,
                    previousTitles: previousTitles,
                    budgetHint: budgetHint,
                    timeHint: timeHint,
                    indoorOutdoor: indoorOutdoor,
                    model: model
                )
            }

            group.addTask { [singleIdeaTimeoutInterval] in
                try await Task.sleep(nanoseconds: UInt64(singleIdeaTimeoutInterval * 1_000_000_000))
                throw URLError(.timedOut)
            }

            guard let first = try await group.next() else {
                throw URLError(.unknown)
            }
            group.cancelAll()
            // Pause so GTMSessionFetcher can finish tearing down before the next getSingleIdea call (avoids "was already running").
            try? await Task.sleep(nanoseconds: 200_000_000)
            return first
        }
    }

    private func performNetworkFetchSingleIdea(
        location: String,
        category: AVCategory,
        index: Int,
        total: Int,
        previousTitles: [String],
        budgetHint: String?,
        timeHint: String?,
        indoorOutdoor: String?,
        model: String
    ) async throws -> AVIdea {
        let data: [String: Any] = [
            "location": location,
            "category": category.rawValue,
            "index": index,
            "total": total,
            "previous_titles": previousTitles,
            "budgetHint": budgetHint ?? "",
            "timeHint": timeHint ?? "",
            "indoorOutdoor": indoorOutdoor ?? "",
            "model": model
        ]
        let raw = try await GetSingleIdeaSerialization.shared.callAndGetData(data)
        guard let resultData = raw as? [String: Any],
              let ideasData = resultData["ideas"] as? [[String: Any]],
              let first = ideasData.first else {
            throw NSError(domain: "AIIdeasService", code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        let jsonData = try JSONSerialization.data(withJSONObject: first)
        let aiIdea = try JSONDecoder().decode(AIIdea.self, from: jsonData)
        return aiIdea.asAVIdea
    }

    private func streamFromBatchFallback(
        location: String,
        category: AVCategory,
        budgetHint: String?,
        timeHint: String?,
        indoorOutdoor: String?,
        model: String,
        onIdea: @escaping (AVIdea) async -> Void
    ) async throws -> [AVIdea] {
        let fallbackStartedAt = Date()
        let effectiveTimeHint = normalizedTimeHint(for: category, requestedTimeHint: timeHint)
        let data: [String: Any] = [
            "location": location,
            "category": category.rawValue,
            "budgetHint": budgetHint ?? "",
            "timeHint": effectiveTimeHint,
            "indoorOutdoor": indoorOutdoor ?? "",
            "userQuery": "",
            "model": model
        ]

        let batchIdeas = try await performNetworkFetchIdeas(
            location: location,
            category: category,
            data: data
        )

        var streamed: [AVIdea] = []
        var seenTitles = Set<String>()
        for idea in batchIdeas where seenTitles.insert(idea.title.lowercased()).inserted {
            streamed.append(idea)
            await onIdea(idea)
            try? await Task.sleep(nanoseconds: 250_000_000)
            if streamed.count == 3 { break }
        }

        guard !streamed.isEmpty else {
            throw NSError(
                domain: "AIIdeasService",
                code: -13,
                userInfo: [NSLocalizedDescriptionKey: "Fallback batch returned no unique ideas."]
            )
        }

        print("🤖 AI Service: ✅ Batch fallback streamed \(streamed.count) ideas")
        logStageDuration(stage: "batch_fallback_streamed", startedAt: fallbackStartedAt, location: location, category: category)
        return streamed
    }

    /// Extra detail for Firebase callable failures (often shows server message behind generic "INTERNAL").
    private func logCallableNSError(_ err: NSError, label: String) {
        var bits: [String] = []
        if let v = err.userInfo[NSLocalizedFailureReasonErrorKey] {
            bits.append("failureReason=\(v)")
        }
        for key in ["FIRFunctionsErrorDetails", "FunctionsErrorDetails"] {
            if let v = err.userInfo[key] {
                bits.append("\(key)=\(v)")
            }
        }
        // Dynamic keys (SDK version differences)
        for (k, v) in err.userInfo {
            let ks = String(describing: k)
            if ks.localizedCaseInsensitiveContains("function") || ks.localizedCaseInsensitiveContains("firebase") {
                if !bits.contains(where: { $0.hasPrefix("\(ks)=") }) {
                    bits.append("\(ks)=\(v)")
                }
            }
        }
        if !bits.isEmpty {
            print("🤖 AI Service: [\(label)] NSError userInfo → \(bits.joined(separator: " | "))")
        }
    }

    private func isRetryableNetworkError(_ error: Error) -> Bool {
        let err = error as NSError
        return (err.domain == "com.firebase.functions" && (err.code == 13 || err.code == 4)) ||
        (err.domain == NSURLErrorDomain && err.code == -1001) ||
        error.localizedDescription.lowercased().contains("timeout") ||
        error.localizedDescription.lowercased().contains("deadline")
    }

    private func normalizedTimeHint(for category: AVCategory, requestedTimeHint: String?) -> String {
        let trimmed = requestedTimeHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categoryConstraint: String?
        switch category {
        case .special:
            categoryConstraint = "Only include upcoming events happening from today through the next 14 days. Do not suggest past events. Include the exact event date (day and month) in the title or blurb, and prefer Eventbrite or official venue booking links when available."
        case .local:
            categoryConstraint = "Prioritize truly local-feeling spots and activities: neighborhood coffee shops, VR/game places, gardens, parks, community events, and local hangouts. Avoid tourist attractions and generic travel landmarks."
        default:
            categoryConstraint = nil
        }

        guard let categoryConstraint else { return trimmed }
        if trimmed.isEmpty { return categoryConstraint }
        return "\(trimmed). \(categoryConstraint)"
    }

    private func logStageDuration(stage: String, startedAt: Date, location: String, category: AVCategory) {
        let elapsed = Date().timeIntervalSince(startedAt)
        let elapsedText = String(format: "%.2f", elapsed)
        print("⏱️ AI METRIC: \(stage) | \(streamContext(location: location, category: category)) | duration=\(elapsedText)s")
    }

    private func streamContext(location: String, category: AVCategory) -> String {
        #if canImport(UIKit)
        let appState: String
        switch UIApplication.shared.applicationState {
        case .active: appState = "active"
        case .inactive: appState = "inactive"
        case .background: appState = "background"
        @unknown default: appState = "unknown"
        }
        #else
        let appState = "n/a"
        #endif
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "on" : "off"
        return "location=\(location) | category=\(category.rawValue) | appState=\(appState) | lowPower=\(lowPower)"
    }
    
    private func recordSearchUsage(location: String, category: AVCategory) async {
        let searchQuery = "\(location) \(category.rawValue)"
        await subscriptionManager.recordSearch(searchQuery: searchQuery)
        print("🤖 AI Service: ✅ Search usage recorded successfully")
    }
    
    private func cacheIdeas(ideas: [AVIdea], location: String, category: AVCategory) async {
        let userId = firebaseManager.currentUser?.uid ?? "anonymous"
        await cacheService.cacheIdeasFromAI(
            ideas: ideas,
            location: location,
            category: category,
            budgetHint: nil,
            timeHint: nil,
            indoorOutdoor: nil,
            userId: userId
        )
    }
    
    // MARK: - Location Validation
    
    /// Fast, lightweight validation – AI handles semantics
    private func validateLocationFast(_ location: String) -> Bool {
        return location.count > 1
    }
}

// MARK: - Extensions

extension AVCategory {
    static var general: AVCategory { .date }
}

