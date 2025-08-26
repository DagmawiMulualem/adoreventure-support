//
//  SubscriptionManager.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/24/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import StoreKit

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isSubscribed = false
    @Published var dailySearchesUsed = 0
    @Published var dailySearchesLimit = 2
    @Published var lastSearchDate: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var products: [Product] = []
    
    private init() {
        print("💳 Subscription: SubscriptionManager initialized")
        loadFromUserDefaults() // Load from local storage first
        Task {
            await loadSubscriptionStatus()
            await loadDailySearchCount()
        }
    }
    
    // MARK: - Persistence
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(dailySearchesUsed, forKey: "dailySearchesUsed")
        if let lastDate = lastSearchDate {
            UserDefaults.standard.set(lastDate, forKey: "lastSearchDate")
        }
        UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed")
    }
    
    private func loadFromUserDefaults() {
        dailySearchesUsed = UserDefaults.standard.integer(forKey: "dailySearchesUsed")
        lastSearchDate = UserDefaults.standard.object(forKey: "lastSearchDate") as? Date
        isSubscribed = UserDefaults.standard.bool(forKey: "isSubscribed")
    }
    
    // MARK: - Search Tracking
    
    func canPerformSearch() async -> Bool {
        await loadDailySearchCount()
        
        // If subscribed, always allow
        if isSubscribed {
            return true
        }
        
        // Check if it's a new day
        if let lastDate = lastSearchDate {
            let calendar = Calendar.current
            if !calendar.isDate(lastDate, inSameDayAs: Date()) {
                // New day, reset count
                await resetDailySearchCount()
                return true
            }
        }
        
        // Check if under daily limit
        return dailySearchesUsed < dailySearchesLimit
    }
    
    func recordSearch() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let today = Date()
        let calendar = Calendar.current
        
        // Check if it's a new day
        if let lastDate = lastSearchDate {
            if !calendar.isDate(lastDate, inSameDayAs: today) {
                // New day, reset count
                await resetDailySearchCount()
            }
        }
        
        // Update on main thread
        await MainActor.run {
            dailySearchesUsed += 1
        }
        
        // Save to local storage
        saveToUserDefaults()
        
        // Update Firestore - create document if it doesn't exist
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.setData([
                "dailySearchesUsed": dailySearchesUsed,
                "lastSearchDate": FieldValue.serverTimestamp(),
                "isSubscribed": isSubscribed,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true) // merge: true will create if doesn't exist, update if exists
            
            print("💳 Subscription: Search recorded - \(dailySearchesUsed)/\(dailySearchesLimit)")
        } catch {
            print("💳 Subscription: Error recording search - \(error.localizedDescription)")
        }
    }
    
    private func loadDailySearchCount() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let userRef = db.collection("users").document(userId)
            let document = try await userRef.getDocument()
            
            if let data = document.data() {
                await MainActor.run {
                    self.dailySearchesUsed = data["dailySearchesUsed"] as? Int ?? 0
                    if let timestamp = data["lastSearchDate"] as? Timestamp {
                        self.lastSearchDate = timestamp.dateValue()
                    }
                }
            }
        } catch {
            print("💳 Subscription: Error loading search count - \(error.localizedDescription)")
        }
    }
    
    private func resetDailySearchCount() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        await MainActor.run {
            self.dailySearchesUsed = 0
            self.lastSearchDate = Date()
        }
        
        // Save to local storage
        saveToUserDefaults()
        
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.setData([
                "dailySearchesUsed": 0,
                "lastSearchDate": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("💳 Subscription: Daily search count reset")
        } catch {
            print("💳 Subscription: Error resetting search count - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Subscription Management
    
    private func loadSubscriptionStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let userRef = db.collection("users").document(userId)
            let document = try await userRef.getDocument()
            
            if let data = document.data() {
                await MainActor.run {
                    self.isSubscribed = data["isSubscribed"] as? Bool ?? false
                }
            }
        } catch {
            print("💳 Subscription: Error loading subscription status - \(error.localizedDescription)")
        }
    }
    
    func updateSubscriptionStatus(_ isSubscribed: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.setData([
                "isSubscribed": isSubscribed,
                "subscriptionDate": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true) // Use merge to create document if it doesn't exist
            
            await MainActor.run {
                self.isSubscribed = isSubscribed
            }
            
            // Save to local storage
            saveToUserDefaults()
            
            print("💳 Subscription: ✅ Status updated - \(isSubscribed)")
        } catch {
            print("💳 Subscription: ❌ Error updating subscription status - \(error.localizedDescription)")
        }
    }
    
    // Temporary method for testing - remove in production
    func toggleSubscriptionForTesting() async {
        await updateSubscriptionStatus(!isSubscribed)
    }
    
    // MARK: - Stripe Integration
    
    func loadProducts() async {
        // Stripe products are loaded in StripePaymentService
        print("💳 Subscription: Stripe products loaded")
    }
    
    func purchaseSubscription() async -> Bool {
        // This method is now handled by StripePaymentService
        print("💳 Subscription: Stripe purchase flow initiated")
        return false
    }
    
    func restorePurchases() async -> Bool {
        // Check Stripe subscription status
        print("💳 Subscription: Checking Stripe subscription status")
        
        let stripeService = StripePaymentService.shared
        if let status = await stripeService.getSubscriptionStatus() {
            let isActive = status["isActive"] as? Bool ?? false
            await updateSubscriptionStatus(isActive)
            return isActive
        }
        return false
    }
    
    // MARK: - Helper Methods
    
    var searchesRemaining: Int {
        return max(0, dailySearchesLimit - dailySearchesUsed)
    }
    
    var isSearchLimitReached: Bool {
        return !isSubscribed && dailySearchesUsed >= dailySearchesLimit
    }
    
    var searchLimitMessage: String {
        if isSubscribed {
            return "Unlimited searches with your subscription! ✨"
        } else {
            return "\(searchesRemaining) of \(dailySearchesLimit) free searches remaining today"
        }
    }
    
    func clearAllData() {
        print("💳 Subscription: Clearing all subscription data...")
        
        // Reset all subscription data
        isSubscribed = false
        dailySearchesUsed = 0
        lastSearchDate = nil
        isLoading = false
        errorMessage = nil
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "dailySearchesUsed")
        UserDefaults.standard.removeObject(forKey: "lastSearchDate")
        UserDefaults.standard.removeObject(forKey: "isSubscribed")
        
        print("💳 Subscription: All subscription data cleared")
    }
}
