//
//  IdeaCacheService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import CryptoKit

import UIKit

// MARK: - Cache Models

struct CachedIdea: Codable, Identifiable {
    let id: String // Stable ideaId (hash of title|placeId|city|category)
    let title: String
    let blurb: String
    let rating: Double
    let place: String
    let duration: String
    let priceRange: String
    let tags: [String]
    let address: String?
    let phone: String?
    let website: String?
    let bookingURL: String?
    let bestTime: String?
    let hours: [String]?
    let createdAt: Date
    let batchId: String
    
    init(from avIdea: AVIdea, batchId: String, location: String, category: String) {
        self.id = Self.generateIdeaId(title: avIdea.title, place: avIdea.place, location: location, category: category)
        self.title = avIdea.title
        self.blurb = avIdea.blurb
        self.rating = avIdea.rating
        self.place = avIdea.place
        self.duration = avIdea.duration
        self.priceRange = avIdea.priceRange
        self.tags = avIdea.tags
        self.address = avIdea.address
        self.phone = avIdea.phone
        self.website = avIdea.website
        self.bookingURL = avIdea.bookingURL
        self.bestTime = avIdea.bestTime
        self.hours = avIdea.hours
        self.createdAt = Date()
        self.batchId = batchId
    }
    
    init(id: String, title: String, blurb: String, rating: Double, place: String, duration: String, priceRange: String, tags: [String], address: String?, phone: String?, website: String?, bookingURL: String?, bestTime: String?, hours: [String]?, createdAt: Date, batchId: String) {
        self.id = id
        self.title = title
        self.blurb = blurb
        self.rating = rating
        self.place = place
        self.duration = duration
        self.priceRange = priceRange
        self.tags = tags
        self.address = address
        self.phone = phone
        self.website = website
        self.bookingURL = bookingURL
        self.bestTime = bestTime
        self.hours = hours
        self.createdAt = createdAt
        self.batchId = batchId
    }
    
    var asAVIdea: AVIdea {
        AVIdea(
            title: title,
            blurb: blurb,
            rating: rating,
            place: place,
            duration: duration,
            priceRange: priceRange,
            tags: tags,
            address: address,
            phone: phone,
            website: website,
            bookingURL: bookingURL,
            bestTime: bestTime,
            hours: hours
        )
    }
    
    static func generateIdeaId(title: String, place: String, location: String, category: String) -> String {
        // Use title-only normalized ID to match AVIdea's deterministic ID
        // This ensures the same venue always has the same ID regardless of place/location/category
        let normalized = title.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return normalized.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }
}

struct UserCursor: Codable {
    let userId: String
    let selectionKey: String
    let seenIds: [String]
    let nextIndex: Int
    var lastUpdated: Date
    
    init(userId: String, selectionKey: String, seenIds: [String] = [], nextIndex: Int = 0) {
        self.userId = userId
        self.selectionKey = selectionKey
        self.seenIds = seenIds
        self.nextIndex = nextIndex
        self.lastUpdated = Date()
    }
}

struct SharedPool: Codable {
    let selectionKey: String
    var ideaIds: [String] // Ordered list of idea IDs
    var totalIdeas: Int
    var lastUpdated: Date
    var batchIds: [String] // Track which batches contributed to this pool
    
    init(selectionKey: String, ideaIds: [String] = [], batchIds: [String] = []) {
        self.selectionKey = selectionKey
        self.ideaIds = ideaIds
        self.totalIdeas = ideaIds.count
        self.lastUpdated = Date()
        self.batchIds = batchIds
    }
    
    mutating func updateIdeas(_ newIdeas: [String], batchId: String) {
        ideaIds.append(contentsOf: newIdeas)
        totalIdeas = ideaIds.count
        lastUpdated = Date()
        batchIds.append(batchId)
    }
}

// MARK: - Selection Key Generator

struct SelectionKey {
    static func generate(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil
    ) -> String {
        let components = [
            location.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            category.rawValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            (budgetHint ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            (timeHint ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            (indoorOutdoor ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        let combined = components.joined(separator: "|")
        return combined.data(using: .utf8)?.sha256().hexString ?? UUID().uuidString
    }
}

// MARK: - Main Cache Service

@MainActor
class IdeaCacheService: ObservableObject {
    static let shared = IdeaCacheService()
    
    private let db = Firestore.firestore()
    private let ideasPerPack = 3
    private let backgroundTopUpSize = 6
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main method to get ideas with caching
    func getIdeas(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> [AVIdea] {
        let selectionKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor
        )
        
        let userId = FirebaseManager.shared.currentUser?.uid ?? "anonymous"
        
        print("🗄️ Cache: Getting ideas for selectionKey: \(selectionKey)")
        
        // Check if we have enough unseen ideas in the shared pool
        if !forceRefresh {
            if let cachedIdeas = await getCachedIdeas(
                selectionKey: selectionKey,
                userId: userId,
                count: ideasPerPack
            ) {
                print("🗄️ Cache: Returning \(cachedIdeas.count) cached ideas")
                
                // Record search and background top-up in background (don't wait)
                Task {
                    await recordSearch(location: location, category: category)
                    // Delay so multiple restored category tabs don’t all start Callable top-ups in the same second as a user-initiated search.
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await backgroundTopUp(
                        selectionKey: selectionKey,
                        location: location,
                        category: category,
                        budgetHint: budgetHint,
                        timeHint: timeHint,
                        indoorOutdoor: indoorOutdoor
                    )
                }
                
                return cachedIdeas
            }
        }
        
        // Cold start or force refresh - generate new ideas
        print("🗄️ Cache: Cold start - generating new ideas")
        return try await coldStart(
            selectionKey: selectionKey,
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor,
            userId: userId
        )
    }
    
    /// Get ideas with streaming: call onIdea for each idea as it becomes available (from cache with delay, or from AI as each is ready).
    func getIdeasStreaming(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        forceRefresh: Bool = false,
        onBatchFallbackReset: (@Sendable () async -> Void)? = nil,
        onIdea: @escaping (AVIdea) async -> Void
    ) async throws -> [AVIdea] {
        let pipelineStartedAt = Date()
        let selectionKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor
        )
        let userId = FirebaseManager.shared.currentUser?.uid ?? "anonymous"
        
        // Cache hit: stream cached ideas one by one with short delay
        if !forceRefresh,
           let cachedIdeas = await getCachedIdeas(
               selectionKey: selectionKey,
               userId: userId,
               count: ideasPerPack
           ) {
            print("🗄️ Cache: Streaming \(cachedIdeas.count) cached ideas one by one")
            for idea in cachedIdeas {
                await onIdea(idea)
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s between cards
            }
            let elapsed = Date().timeIntervalSince(pipelineStartedAt)
            let elapsedText = String(format: "%.2f", elapsed)
            print("⏱️ CACHE METRIC: getIdeasStreaming cache_hit | location=\(location) | category=\(category.rawValue) | duration=\(elapsedText)s")
            Task {
                await recordSearch(location: location, category: category)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await backgroundTopUp(selectionKey: selectionKey, location: location, category: category, budgetHint: budgetHint, timeHint: timeHint, indoorOutdoor: indoorOutdoor)
            }
            return cachedIdeas
        }
        
        // Cold start: use AI streaming (each card appears when that idea is ready)
        print("🗄️ Cache: Cold start - streaming ideas one by one from AI")
        let ideas = try await AIIdeasService.shared.fetchIdeasStreaming(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor,
            onBatchFallbackReset: onBatchFallbackReset,
            onIdea: onIdea
        )
        let elapsed = Date().timeIntervalSince(pipelineStartedAt)
        let elapsedText = String(format: "%.2f", elapsed)
        print("⏱️ CACHE METRIC: getIdeasStreaming ai_stream | location=\(location) | category=\(category.rawValue) | duration=\(elapsedText)s")
        // Update user cursor so "More Ideas" doesn't return these again
        let ideaIds = ideas.map { CachedIdea.generateIdeaId(title: $0.title, place: $0.place, location: location, category: category.rawValue) }
        let cursor = try await getUserCursor(userId: userId, selectionKey: selectionKey)
        let newCursor = UserCursor(
            userId: userId,
            selectionKey: selectionKey,
            seenIds: cursor.seenIds + ideaIds,
            nextIndex: cursor.nextIndex + ideas.count
        )
        await saveUserCursor(newCursor)
        print("🗄️ Cache: Updated cursor with \(ideaIds.count) seen ideas")
        return ideas
    }
    
    /// Public wrapper for caching ideas generated by AI using the same selectionKey logic.
    func cacheIdeasFromAI(
        ideas: [AVIdea],
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        userId: String
    ) async {
        let selectionKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor
        )
        
        await cacheIdeas(
            ideas: ideas,
            selectionKey: selectionKey,
            location: location,
            category: category,
            userId: userId
        )
    }
    
    /// Get more ideas (continues from where user left off). Never returns ideas whose ids are in excludeIds. previousTitles are sent to backend so it returns different ideas.
    func getMoreIdeas(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        excludeIds: Set<String> = [],
        previousTitles: [String] = []
    ) async throws -> [AVIdea] {
        let selectionKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor
        )
        
        let userId = FirebaseManager.shared.currentUser?.uid ?? "anonymous"
        
        print("🗄️ Cache: Getting more ideas for selectionKey: \(selectionKey) excludeIds.count=\(excludeIds.count)")
        
        // Try to get more cached ideas, then filter out any already shown (client-side guard)
        if let cachedIdeas = await getCachedIdeas(
            selectionKey: selectionKey,
            userId: userId,
            count: ideasPerPack
        ) {
            let fresh = cachedIdeas.filter { !excludeIds.contains($0.id) }
            if !fresh.isEmpty {
                print("🗄️ Cache: Returning \(fresh.count) more cached ideas (filtered from \(cachedIdeas.count))")
                Task { await recordSearch(location: location, category: category) }
                return fresh
            }
        }
        
        // Need to generate more ideas; pass excludeIds and previousTitles so we never return duplicates
        print("🗄️ Cache: Need to generate more ideas (excluding \(excludeIds.count) ids, \(previousTitles.count) titles)")
        return try await generateAndCacheIdeas(
            selectionKey: selectionKey,
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor,
            userId: userId,
            excludeIds: excludeIds,
            previousTitles: previousTitles
        )
    }
    
    /// Get ideas from cache only (no AI calls). Returns nil if not enough cached.
    func getCachedIdeasOnly(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        count: Int = 6
    ) async -> [AVIdea]? {
        let selectionKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor
        )
        
        let userId = FirebaseManager.shared.currentUser?.uid ?? "anonymous"
        
        return await getCachedIdeas(
            selectionKey: selectionKey,
            userId: userId,
            count: count
        )
    }
    
    /// Reset user cursor to start over
    func resetCursor(
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil
    ) async {
        let selectionKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor
        )
        
        let userId = FirebaseManager.shared.currentUser?.uid ?? "anonymous"
        
        print("🗄️ Cache: Resetting cursor for selectionKey: \(selectionKey)")
        
        let cursor = UserCursor(userId: userId, selectionKey: selectionKey)
        await saveUserCursor(cursor)
    }
    
    // MARK: - Private Methods
    
    private func getCachedIdeas(
        selectionKey: String,
        userId: String,
        count: Int
    ) async -> [AVIdea]? {
        do {
            // Fetch shared pool and user cursor in parallel for better performance
            async let poolTask = getSharedPool(selectionKey: selectionKey)
            async let cursorTask = getUserCursor(userId: userId, selectionKey: selectionKey)
            
            let pool = try await poolTask
            let cursor = try await cursorTask
            
            guard !pool.ideaIds.isEmpty else { return nil }
            
            // Remove already seen ideas
            let unseen = pool.ideaIds.filter { !cursor.seenIds.contains($0) }

            // Shuffle so order always feels new
            let shuffled = unseen.shuffled()

            // Take only what we need
            let ideaIds = Array(shuffled.prefix(count))
            
            guard ideaIds.count >= count else { return nil }
            
            // Fetch the actual idea data
            let ideas = try await fetchIdeasByIds(ideaIds)
            
            // Update cursor in background (don't wait for it)
            let newNextIndex = cursor.nextIndex + ideaIds.count
            let newCursor = UserCursor(
                userId: userId,
                selectionKey: selectionKey,
                seenIds: cursor.seenIds + ideaIds,
                nextIndex: newNextIndex
            )
            Task {
                await saveUserCursor(newCursor)
            }
            
            return ideas.map { $0.asAVIdea }
            
        } catch {
            print("🗄️ Cache: Error getting cached ideas: \(error)")
            return nil
        }
    }
    
    private func coldStart(
        selectionKey: String,
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        userId: String
    ) async throws -> [AVIdea] {
        do {
            // First, try instant tiered fallback cache (exact key, then looser/global keys)
            // Now filters by user's seen ideas to avoid duplicates
            if let fallback = await getTieredFallbackIdeas(
                primarySelectionKey: selectionKey,
                location: location,
                category: category,
                budgetHint: budgetHint,
                timeHint: timeHint,
                indoorOutdoor: indoorOutdoor,
                count: ideasPerPack,
                userId: userId
            ) {
                print("🗄️ Cache: ⚡ Using instant tiered fallback cache (filtered by seen)")
                
                // Generate fresh ideas in background (don't wait)
                Task {
                    _ = try? await self.generateAndCacheIdeas(
                        selectionKey: selectionKey,
                        location: location,
                        category: category,
                        budgetHint: budgetHint,
                        timeHint: timeHint,
                        indoorOutdoor: indoorOutdoor,
                        userId: userId
                    )
                }
                
                return fallback
            }
            
            // Generate ideas in background
            let ideas = try await AIIdeasService.shared.fetchIdeas(
                location: location,
                category: category,
                budgetHint: budgetHint,
                timeHint: timeHint,
                indoorOutdoor: indoorOutdoor
            )
            
            // Cache the ideas
            await cacheIdeas(
                ideas: ideas,
                selectionKey: selectionKey,
                location: location,
                category: category,
                userId: userId
            )
            
            // Get the first pack of ideas
            let firstPack = Array(ideas.prefix(ideasPerPack))
            
            // IMPORTANT: Update cursor to mark these ideas as seen
            // This prevents them from being returned again on "More Ideas"
            let ideaIds = firstPack.map { CachedIdea.generateIdeaId(title: $0.title, place: $0.place, location: location, category: category.rawValue) }
            let cursor = try await getUserCursor(userId: userId, selectionKey: selectionKey)
            let newCursor = UserCursor(
                userId: userId,
                selectionKey: selectionKey,
                seenIds: cursor.seenIds + ideaIds,
                nextIndex: cursor.nextIndex + ideaIds.count
            )
            await saveUserCursor(newCursor)
            print("🗄️ Cache: Updated cursor with \(ideaIds.count) seen ideas")
            
            return firstPack
        } catch {
            print("🗄️ Cache: AI generation failed, trying fallback...")
            
            // Try to get any cached ideas as fallback (filtered by seen)
            if let fallbackIdeas = await getTieredFallbackIdeas(
                primarySelectionKey: selectionKey,
                location: location,
                category: category,
                budgetHint: budgetHint,
                timeHint: timeHint,
                indoorOutdoor: indoorOutdoor,
                count: ideasPerPack,
                userId: userId
            ) {
                print("🗄️ Cache: Using tiered fallback cached ideas after AI failure")
                return fallbackIdeas
            }
            
            // If no fallback available, re-throw the error
            throw error
        }
    }
    
    private func generateAndCacheIdeas(
        selectionKey: String,
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil,
        userId: String,
        excludeIds: Set<String> = [],
        previousTitles: [String] = []
    ) async throws -> [AVIdea] {
        let ideas = try await AIIdeasService.shared.fetchIdeas(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoor,
            previousTitles: previousTitles
        )
        // Only use ideas we haven't already shown (never repeat in "More Ideas")
        let newIdeas = ideas.filter { !excludeIds.contains($0.id) }
        let pack = Array(newIdeas.prefix(ideasPerPack))
        guard !pack.isEmpty else {
            print("🗄️ Cache: All generated ideas were duplicates (excludeIds); returning []")
            return []
        }
        
        await cacheIdeas(
            ideas: pack,
            selectionKey: selectionKey,
            location: location,
            category: category,
            userId: userId
        )
        // Mark these as seen so they aren't returned again from cache
        let ideaIds = pack.map { CachedIdea.generateIdeaId(title: $0.title, place: $0.place, location: location, category: category.rawValue) }
        let cursor = try await getUserCursor(userId: userId, selectionKey: selectionKey)
        let newCursor = UserCursor(
            userId: userId,
            selectionKey: selectionKey,
            seenIds: cursor.seenIds + ideaIds,
            nextIndex: cursor.nextIndex + pack.count
        )
        await saveUserCursor(newCursor)
        print("🗄️ Cache: Generated and cached \(pack.count) new ideas (cursor updated)")
        return pack
    }
    
    private func backgroundTopUp(
        selectionKey: String,
        location: String,
        category: AVCategory,
        budgetHint: String? = nil,
        timeHint: String? = nil,
        indoorOutdoor: String? = nil
    ) async {
        do {
            // Check if pool needs top-up
            let pool = try await getSharedPool(selectionKey: selectionKey)
            if pool.ideaIds.count < backgroundTopUpSize {
                print("🗄️ Cache: Background top-up needed")
                
                let ideas = try await AIIdeasService.shared.fetchIdeas(
                    location: location,
                    category: category,
                    budgetHint: budgetHint,
                    timeHint: timeHint,
                    indoorOutdoor: indoorOutdoor
                )
                
                await cacheIdeas(
                    ideas: ideas,
                    selectionKey: selectionKey,
                    location: location,
                    category: category,
                    userId: "system"
                )
            }
        } catch {
            print("🗄️ Cache: Background top-up failed: \(error)")
        }
    }
    
    private func cacheIdeas(
        ideas: [AVIdea],
        selectionKey: String,
        location: String,
        category: AVCategory,
        userId: String
    ) async {
        // Don't cache empty results (failed searches)
        guard !ideas.isEmpty else {
            print("🗄️ Cache: Skipping cache for empty results (failed search)")
            return
        }
        
        do {
            let batchId = UUID().uuidString
            let cachedIdeas = ideas.map { CachedIdea(from: $0, batchId: batchId, location: location, category: category.rawValue) }
            
            // Get existing pool for this exact selection key
            var pool = try await getSharedPool(selectionKey: selectionKey)
            
            // Dedupe against existing ideas
            let existingIds = Set(pool.ideaIds)
            let newIdeas = cachedIdeas.filter { !existingIds.contains($0.id) }
            
            if newIdeas.isEmpty {
                print("🗄️ Cache: No new ideas to cache (all duplicates)")
                return
            }
            
            // Save individual ideas (only once, shared across all pools)
            for idea in newIdeas {
                try await db.collection("ideas").document(idea.id).setData(idea.dictionary)
            }
            
            // Update primary shared pool using the new method
            pool.updateIdeas(newIdeas.map { $0.id }, batchId: batchId)
            await saveSharedPool(pool)
            
            print("🗄️ Cache: Cached \(newIdeas.count) new ideas for primary key")
            
            // Also update a more generic pool for this location/category (without hints)
            let genericKey = SelectionKey.generate(
                location: location,
                category: category,
                budgetHint: nil,
                timeHint: nil,
                indoorOutdoor: nil
            )
            
            if genericKey != selectionKey {
                do {
                    var genericPool = try await getSharedPool(selectionKey: genericKey)
                    let existingGenericIds = Set(genericPool.ideaIds)
                    let genericNewIds = newIdeas
                        .map { $0.id }
                        .filter { !existingGenericIds.contains($0) }
                    
                    if !genericNewIds.isEmpty {
                        genericPool.updateIdeas(genericNewIds, batchId: batchId)
                        await saveSharedPool(genericPool)
                        print("🗄️ Cache: Also updated generic pool \(genericKey) with \(genericNewIds.count) ideas")
                    }
                } catch {
                    print("🗄️ Cache: Error updating generic pool: \(error)")
                }
            }
            
            // Also update a global pool for this category (location-agnostic ideas)
            let globalKey = SelectionKey.generate(
                location: "global",
                category: category,
                budgetHint: nil,
                timeHint: nil,
                indoorOutdoor: nil
            )
            
            if globalKey != selectionKey && globalKey != genericKey {
                do {
                    var globalPool = try await getSharedPool(selectionKey: globalKey)
                    let existingGlobalIds = Set(globalPool.ideaIds)
                    let globalNewIds = newIdeas
                        .map { $0.id }
                        .filter { !existingGlobalIds.contains($0) }
                    
                    if !globalNewIds.isEmpty {
                        globalPool.updateIdeas(globalNewIds, batchId: batchId)
                        await saveSharedPool(globalPool)
                        print("🗄️ Cache: Also updated global pool \(globalKey) with \(globalNewIds.count) ideas")
                    }
                } catch {
                    print("🗄️ Cache: Error updating global pool: \(error)")
                }
            }
            
        } catch {
            print("🗄️ Cache: Error caching ideas: \(error)")
        }
    }
    
    // MARK: - Firestore Operations
    
    private func getSharedPool(selectionKey: String) async throws -> SharedPool {
        let doc = try await db.collection("pools").document(selectionKey).getDocument()
        
        if let data = doc.data() {
            let pool = try SharedPool.from(dictionary: data)

            // Shuffle once per day for freshness
            let calendar = Calendar.current
            if !calendar.isDateInToday(pool.lastUpdated) {
                var updatedPool = pool
                updatedPool.ideaIds.shuffle()
                updatedPool.lastUpdated = Date()
                await saveSharedPool(updatedPool)
                return updatedPool
            }

            return pool
        } else {
            return SharedPool(selectionKey: selectionKey)
        }
    }
    
    private func saveSharedPool(_ pool: SharedPool) async {
        do {
            try await db.collection("pools").document(pool.selectionKey).setData(pool.dictionary)
        } catch {
            print("🗄️ Cache: Error saving shared pool: \(error)")
        }
    }
    
    private func getUserCursor(userId: String, selectionKey: String) async throws -> UserCursor {
        let doc = try await db.collection("users").document(userId)
            .collection("cursors").document(selectionKey).getDocument()
        
        if let data = doc.data() {
            let cursor = try UserCursor.from(dictionary: data)
            
            // Check if cursor is from a different day and reset if needed
            if !isSameDay(cursor.lastUpdated, Date()) {
                print("🗄️ Cache: Cursor is from different day, resetting...")
                let resetCursor = UserCursor(userId: userId, selectionKey: selectionKey)
                await saveUserCursor(resetCursor)
                return resetCursor
            }
            
            return cursor
        } else {
            return UserCursor(userId: userId, selectionKey: selectionKey)
        }
    }
    
    private func saveUserCursor(_ cursor: UserCursor) async {
        do {
            try await db.collection("users").document(cursor.userId)
                .collection("cursors").document(cursor.selectionKey)
                .setData(cursor.dictionary)
        } catch {
            print("🗄️ Cache: Error saving user cursor: \(error)")
        }
    }
    
    private func fetchIdeasByIds(_ ideaIds: [String]) async throws -> [CachedIdea] {
        // Fetch all documents in parallel using TaskGroup for better performance
        let ideas = try await withThrowingTaskGroup(of: CachedIdea?.self) { group in
            var results: [CachedIdea] = []
            
            // Start all fetch tasks in parallel
            for ideaId in ideaIds {
                group.addTask { [self] in
                    do {
                        let doc = try await self.db.collection("ideas").document(ideaId).getDocument()
                        if let data = doc.data() {
                            return try CachedIdea.from(dictionary: data)
                        }
                        return nil
                    } catch {
                        print("🗄️ Cache: Error fetching idea \(ideaId): \(error)")
                        return nil
                    }
                }
            }
            
            // Collect all results as they complete
            for try await idea in group {
                if let idea = idea {
                    results.append(idea)
                }
            }
            
            return results
        }
        
        // Sort to maintain original order
        return ideas.sorted { idea1, idea2 in
            ideaIds.firstIndex(of: idea1.id) ?? 0 < ideaIds.firstIndex(of: idea2.id) ?? 0
        }
    }
    
    private func getAnyCachedIdeas(selectionKey: String, count: Int, userId: String? = nil) async -> [AVIdea]? {
        do {
            let pool = try await getSharedPool(selectionKey: selectionKey)
            guard !pool.ideaIds.isEmpty else { return nil }

            // Filter out already seen ideas if userId provided
            var availableIds = pool.ideaIds
            if let userId = userId {
                let cursor = try await getUserCursor(userId: userId, selectionKey: selectionKey)
                availableIds = pool.ideaIds.filter { !cursor.seenIds.contains($0) }
            }
            
            guard availableIds.count >= count else { return nil }
            
            // Shuffle and take what we need
            let selectedIds = Array(availableIds.shuffled().prefix(count))
            let ideas = try await fetchIdeasByIds(selectedIds)
            
            // Update cursor if we have a userId
            if let userId = userId {
                let cursor = try await getUserCursor(userId: userId, selectionKey: selectionKey)
                let newCursor = UserCursor(
                    userId: userId,
                    selectionKey: selectionKey,
                    seenIds: cursor.seenIds + selectedIds,
                    nextIndex: cursor.nextIndex + selectedIds.count
                )
                Task {
                    await saveUserCursor(newCursor)
                }
            }

            return ideas.map { $0.asAVIdea }
        } catch {
            print("🗄️ Cache: Fallback failed: \(error)")
            return nil
        }
    }
    
    /// Tiered fallback: try exact key, then generic-without-hints, then global pool for this category.
    private func getTieredFallbackIdeas(
        primarySelectionKey: String,
        location: String,
        category: AVCategory,
        budgetHint: String?,
        timeHint: String?,
        indoorOutdoor: String?,
        count: Int,
        userId: String
    ) async -> [AVIdea]? {
        // 1) Exact selection key - filter by user's seen ideas
        if let exact = await getAnyCachedIdeas(selectionKey: primarySelectionKey, count: count, userId: userId) {
            return exact
        }

        // 2) Same location & category but without budget/time/indoor hints
        let genericKey = SelectionKey.generate(
            location: location,
            category: category,
            budgetHint: nil,
            timeHint: nil,
            indoorOutdoor: nil
        )

        if genericKey != primarySelectionKey,
           let generic = await getAnyCachedIdeas(selectionKey: genericKey, count: count, userId: userId) {
            return generic
        }

        return nil
    }
    
    // MARK: - Helper Methods
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    private func recordSearch(location: String, category: AVCategory) async {
        let searchQuery = "\(location) \(category.rawValue)"
        await FirebaseManager.shared.subscriptionManager.recordSearch(searchQuery: searchQuery)
    }
}

// MARK: - Extensions

extension CachedIdea {
    var dictionary: [String: Any] {
        [
            "id": id,
            "title": title,
            "blurb": blurb,
            "rating": rating,
            "place": place,
            "duration": duration,
            "priceRange": priceRange,
            "tags": tags,
            "address": address as Any,
            "phone": phone as Any,
            "website": website as Any,
            "bookingURL": bookingURL as Any,
            "bestTime": bestTime as Any,
            "hours": hours as Any,
            "createdAt": Timestamp(date: createdAt),
            "batchId": batchId
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> CachedIdea {
        // Handle Firestore Timestamp conversion
        var modifiedDict = dictionary
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            modifiedDict["createdAt"] = timestamp.dateValue()
        }
        
        // Create CachedIdea directly from dictionary values
        guard let id = modifiedDict["id"] as? String,
              let title = modifiedDict["title"] as? String,
              let blurb = modifiedDict["blurb"] as? String,
              let rating = modifiedDict["rating"] as? Double,
              let place = modifiedDict["place"] as? String,
              let duration = modifiedDict["duration"] as? String,
              let priceRange = modifiedDict["priceRange"] as? String,
              let tags = modifiedDict["tags"] as? [String],
              let createdAt = modifiedDict["createdAt"] as? Date,
              let batchId = modifiedDict["batchId"] as? String else {
            throw NSError(domain: "CachedIdea", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid dictionary format"])
        }
        
        let address = modifiedDict["address"] as? String
        let phone = modifiedDict["phone"] as? String
        let website = modifiedDict["website"] as? String
        let bookingURL = modifiedDict["bookingURL"] as? String
        let bestTime = modifiedDict["bestTime"] as? String
        let hours = modifiedDict["hours"] as? [String]
        
        return CachedIdea(
            id: id,
            title: title,
            blurb: blurb,
            rating: rating,
            place: place,
            duration: duration,
            priceRange: priceRange,
            tags: tags,
            address: address,
            phone: phone,
            website: website,
            bookingURL: bookingURL,
            bestTime: bestTime,
            hours: hours,
            createdAt: createdAt,
            batchId: batchId
        )
    }
}

extension UserCursor {
    var dictionary: [String: Any] {
        [
            "userId": userId,
            "selectionKey": selectionKey,
            "seenIds": seenIds,
            "nextIndex": nextIndex,
            "lastUpdated": Timestamp(date: lastUpdated)
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> UserCursor {
        // Handle Firestore Timestamp conversion
        var modifiedDict = dictionary
        if let timestamp = dictionary["lastUpdated"] as? Timestamp {
            modifiedDict["lastUpdated"] = timestamp.dateValue()
        }
        
        // Create UserCursor directly from dictionary values
        guard let userId = modifiedDict["userId"] as? String,
              let selectionKey = modifiedDict["selectionKey"] as? String,
              let seenIds = modifiedDict["seenIds"] as? [String],
              let nextIndex = modifiedDict["nextIndex"] as? Int,
              let lastUpdated = modifiedDict["lastUpdated"] as? Date else {
            throw NSError(domain: "UserCursor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid dictionary format"])
        }
        
        var cursor = UserCursor(userId: userId, selectionKey: selectionKey, seenIds: seenIds, nextIndex: nextIndex)
        cursor.lastUpdated = lastUpdated
        return cursor
    }
}

extension SharedPool {
    var dictionary: [String: Any] {
        [
            "selectionKey": selectionKey,
            "ideaIds": ideaIds,
            "totalIdeas": totalIdeas,
            "lastUpdated": Timestamp(date: lastUpdated),
            "batchIds": batchIds
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> SharedPool {
        // Handle Firestore Timestamp conversion
        var modifiedDict = dictionary
        if let timestamp = dictionary["lastUpdated"] as? Timestamp {
            modifiedDict["lastUpdated"] = timestamp.dateValue()
        }
        
        // Create SharedPool directly from dictionary values
        guard let selectionKey = modifiedDict["selectionKey"] as? String,
              let ideaIds = modifiedDict["ideaIds"] as? [String],
              let totalIdeas = modifiedDict["totalIdeas"] as? Int,
              let lastUpdated = modifiedDict["lastUpdated"] as? Date,
              let batchIds = modifiedDict["batchIds"] as? [String] else {
            throw NSError(domain: "SharedPool", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid dictionary format"])
        }
        
        var pool = SharedPool(selectionKey: selectionKey, ideaIds: ideaIds, batchIds: batchIds)
        pool.lastUpdated = lastUpdated
        pool.totalIdeas = totalIdeas
        return pool
    }
}

extension Data {
    func sha256() -> Data {
        let hash = SHA256.hash(data: self)
        return Data(hash)
    }
    
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}




