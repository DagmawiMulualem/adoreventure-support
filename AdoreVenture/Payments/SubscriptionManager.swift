//
//  SubscriptionManager.swift
//  AdoreVenture
//

import SwiftUI
import Firebase
import FirebaseFirestore

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isSubscribed = false
    @Published var credits = 3000
    @Published var isLoading = false
    @Published var showSubscriptionPrompt = false
    @Published var showPaymentSheet = false
    @Published var accountStatus: AccountStatus = .active
    @Published var subscriptionEndDate: Date?
    @Published var isCancellationScheduled = false
    @Published var selectedModel: AIModel = .gpt4oMini
    @Published var currentPlan: SubscriptionPlan = .monthly
    @Published var showAdminPanel = false
    
    // MARK: - Credit System Configuration
    private let firstAccountCredits = 3000
    private let additionalAccountCredits = 50
    private let firstAccountAwardedKey = "deviceFirstAccountCreditsAwarded"
    
    // Special tester account
    private let testerEmail = "dagmawi.m.mulualem@gmail.com"
    private let testerCredits = 10000
    
    // Make FirebaseManager lazy to avoid circular dependency
    private lazy var firebaseManager: FirebaseManager = {
        return FirebaseManager.shared
    }()
    
    private init() {
        loadSubscriptionStatus()
    }
    
    // MARK: - Credit System Methods
    
    /// Record new account creation (simplified - no device restrictions)
    func recordNewAccountCreation(email: String, userId: String) async {
        print("📱 Credit System: New account recorded for \(email)")
        // No device restrictions - just log the account creation
    }
    
    /// Track if initial credits have been set for this session
    private var initialCreditsSet = false
    
    // MARK: - Enums
    
    enum AccountStatus: String, CaseIterable {
        case active = "active"
        case restricted = "restricted"
    }
    
    enum AIModel: String, CaseIterable {
        case gpt4oMini = "gpt-4o-mini"
        case gpt4o = "gpt-4o"
        case gpt4Turbo = "gpt-4-turbo"
        case gpt35Turbo = "gpt-3.5-turbo"
        case geminiFlash = "gemini-1.5-flash"
        
        var displayName: String {
            switch self {
            case .gpt4oMini: return "GPT-4o Mini"
            case .gpt4o: return "GPT-4o"
            case .gpt4Turbo: return "GPT-4 Turbo"
            case .gpt35Turbo: return "GPT-3.5 Turbo"
            case .geminiFlash: return "Gemini 1.5 Flash"
            }
        }
        
        var description: String {
            switch self {
            case .gpt4oMini: return "Fast & efficient"
            case .gpt4o: return "Most advanced"
            case .gpt4Turbo: return "Ultimate performance"
            case .gpt35Turbo: return "Quick responses"
            case .geminiFlash: return "Fast & experimental"
            }
        }
        
        var isPremiumOnly: Bool {
            switch self {
            case .gpt4oMini: return false
            case .gpt4o: return true
            case .gpt4Turbo: return true
            case .gpt35Turbo: return false
            case .geminiFlash: return false
            }
        }
    }
    
    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "monthly"
        case yearly = "yearly"
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
        
        var price: Double {
            switch self {
            case .monthly: return 9.99
            case .yearly: return 99.99
            }
        }
        
        var savings: String {
            switch self {
            case .monthly: return ""
            case .yearly: return "Save 17%"
            }
        }
        
        var isPopular: Bool {
            switch self {
            case .monthly: return false
            case .yearly: return true
            }
        }
    }
    
    
    
    // MARK: - Credit Management
    
    func useCredits(_ amount: Int) {
        let oldCredits = credits
        credits = max(0, credits - amount)
        saveCredits()
        
        print("📱 Credit System: 🔄 Credits changed from \(oldCredits) to \(credits) - syncing to Firestore...")
        
        // Also sync to Firestore to ensure credits persist across devices and sessions
        Task {
            do {
                try await saveCreditsToFirestore()
                print("📱 Credit System: ✅ Credits synced to Firestore after use: \(credits)")
            } catch {
                print("📱 Credit System: ❌ Failed to sync credits to Firestore: \(error)")
            }
        }
    }
    
    func addCredits(_ amount: Int) {
        credits += amount
        saveCredits()
        
        // Also sync to Firestore to ensure credits persist across devices and sessions
        Task {
            do {
                try await saveCreditsToFirestore()
                print("📱 Credit System: ✅ Credits synced to Firestore after adding: \(credits)")
            } catch {
                print("📱 Credit System: ❌ Failed to sync credits to Firestore: \(error)")
            }
        }
    }
    
    /// Give bonus credits when AI has issues (e.g., timeout) - a gift for user's patience
    func giveBonusCreditsForIssue() {
        let bonusAmount = 50
        credits += bonusAmount
        saveCredits()
        
        print("📱 Credit System: 🎁 Gave \(bonusAmount) bonus credits for patience. New balance: \(credits)")
        
        // Also sync to Firestore
        Task {
            do {
                try await saveCreditsToFirestore()
                print("📱 Credit System: ✅ Bonus credits synced to Firestore: \(credits)")
            } catch {
                print("📱 Credit System: ❌ Failed to sync bonus credits to Firestore: \(error)")
            }
        }
    }
    
    func hasEnoughCredits(_ amount: Int) -> Bool {
        return credits >= amount
    }
    
    // MARK: - Subscription Management
    
    func loadSubscriptionStatus() {
        // Load from UserDefaults or Firebase
        if let savedCredits = UserDefaults.standard.object(forKey: "userCredits") as? Int {
            credits = savedCredits
            print("📱 Credit System: Loaded \(credits) credits from UserDefaults")
        } else {
            // If no saved credits, check if this is a first-time user on this device
            Task {
                await checkAndSetInitialCredits()
            }
        }
        
        if let savedStatus = UserDefaults.standard.string(forKey: "subscriptionStatus"),
           let status = AccountStatus(rawValue: savedStatus) {
            accountStatus = status
        }
    }
    
    /// Onboarding credits (no popup): first new account on this device gets `firstAccountCredits` (3000);
    /// additional accounts on the same device get `additionalAccountCredits` (50). See `firstAccountAwardedKey`.
    func checkAndSetInitialCredits() async {
        // Prevent multiple credit assignments in the same session
        guard !initialCreditsSet else {
            print("📱 Credit System: Initial credits already set for this session")
            return
        }
        
        // Always sync with Firestore when checking credits to ensure accuracy
        // This prevents credits from being reset when users sign out and back in
        print("📱 Credit System: Syncing credits with Firestore...")
        
        guard let userId = firebaseManager.currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if userDoc.exists {
                // For existing users, just sync their current credits from Firestore
                // Don't modify their credits unless they have 0 or are a tester
                let userData = userDoc.data()
                let savedCredits = userData?["credits"] as? Int ?? 0
                
                if savedCredits > 0 {
                    // User already has credits - just sync them
                    await MainActor.run {
                        credits = savedCredits
                    }
                    saveCredits()
                    print("📱 Credit System: Existing user - synced \(savedCredits) credits from Firestore")
                } else if isTesterAccount() {
                    // Tester account - ensure they have 6000 credits
                    await MainActor.run {
                        credits = testerCredits
                    }
                    saveCredits()
                    
                    // Save to Firestore
                    do {
                        try await saveCreditsToFirestore()
                        print("📱 Credit System: Successfully ensured tester has \(testerCredits) credits in Firestore")
                    } catch {
                        print("📱 Credit System: Error saving tester credits to Firestore: \(error)")
                    }
                    
                    print("📱 Credit System: Tester account - ensured \(testerCredits) credits (NO popup)")
                } else {
                    // Existing user with 0 credits - give baseline credits
                    await MainActor.run {
                        credits = additionalAccountCredits
                    }
                    saveCredits()
                    
                    // Save to Firestore
                    do {
                        try await saveCreditsToFirestore()
                        print("📱 Credit System: Successfully gave existing user baseline \(additionalAccountCredits) credits")
                    } catch {
                        print("📱 Credit System: Error saving baseline credits to Firestore: \(error)")
                    }
                    
                    print("📱 Credit System: Existing user with 0 credits - gave baseline \(additionalAccountCredits) credits")
                }
                
                // Mark that initial credits have been set for this session
                initialCreditsSet = true
                return
            }
            
            if !userDoc.exists {
                // Check if this is the tester account
                if isTesterAccount() {
                    // Tester account - give 6000 credits, no popup needed
                    await MainActor.run {
                        credits = testerCredits
                    }
                    
                    // Save to UserDefaults first
                    saveCredits()
                    print("📱 Credit System: Tester account - assigned \(testerCredits) credits (NO popup)")
                    
                    // Then save to Firestore with retry logic
                    var firestoreSaveSuccess = false
                    var retryCount = 0
                    while !firestoreSaveSuccess && retryCount < 3 {
                        do {
                            try await saveCreditsToFirestore()
                            firestoreSaveSuccess = true
                            print("📱 Credit System: Successfully saved \(testerCredits) credits to Firestore for tester")
                        } catch {
                            retryCount += 1
                            print("📱 Credit System: Firestore save attempt \(retryCount) failed: \(error)")
                            if retryCount < 3 {
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                            }
                        }
                    }
                    
                    if !firestoreSaveSuccess {
                        print("📱 Credit System: WARNING - Failed to save \(testerCredits) credits to Firestore after 3 attempts")
                    }
                    
                    // Verify credits are properly saved
                    await verifyCreditsSaved()
                    
                } else {
                    // Regular new user: first account on this device gets 3000, later new accounts get 50.
                    let isFirstAccountOnDevice = !UserDefaults.standard.bool(forKey: firstAccountAwardedKey)
                    let onboardingCredits = isFirstAccountOnDevice ? firstAccountCredits : additionalAccountCredits
                    
                    await MainActor.run {
                        credits = onboardingCredits
                    }
                    
                    // Save to UserDefaults first
                    saveCredits()
                    print("📱 Credit System: Saved \(onboardingCredits) credits to UserDefaults for new user")

                    // Save to Firestore with retry logic
                    var firestoreSaveSuccess = false
                    var retryCount = 0
                    while !firestoreSaveSuccess && retryCount < 3 {
                        do {
                            try await saveCreditsToFirestore()
                            firestoreSaveSuccess = true
                            print("📱 Credit System: Successfully saved \(onboardingCredits) credits to Firestore for new user")
                        } catch {
                            retryCount += 1
                            print("📱 Credit System: Firestore save attempt \(retryCount) failed: \(error)")
                            if retryCount < 3 {
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                            }
                        }
                    }

                    if !firestoreSaveSuccess {
                        print("📱 Credit System: WARNING - Failed to save \(onboardingCredits) credits to Firestore after 3 attempts")
                    }

                    // Mark first-account grant consumed on this device
                    if isFirstAccountOnDevice {
                        UserDefaults.standard.set(true, forKey: firstAccountAwardedKey)
                    }

                    print("📱 Credit System: New user setup complete - assigned \(onboardingCredits) credits")
                }
                
                // Mark that initial credits have been set for this session
                initialCreditsSet = true
            }
                
        } catch {
            print("📱 Credit System: Error checking initial credits: \(error)")
        }
    }
    
    /// Verify credits are properly saved in both UserDefaults and Firestore
    func verifyCreditsSaved() async {
        guard let userId = firebaseManager.currentUser?.uid else { return }
        
        // Check UserDefaults
        let localCredits = UserDefaults.standard.object(forKey: "userCredits") as? Int ?? 0
        print("📱 Credit System: UserDefaults credits: \(localCredits)")
        
        // Check Firestore
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if userDoc.exists {
                let firestoreCredits = userDoc.data()?["credits"] as? Int ?? 0
                print("📱 Credit System: Firestore credits: \(firestoreCredits)")
                
                if localCredits == firestoreCredits {
                    print("📱 Credit System: ✅ Credits are properly synchronized between UserDefaults and Firestore")
                } else {
                    print("📱 Credit System: ⚠️ Credits mismatch - UserDefaults: \(localCredits), Firestore: \(firestoreCredits)")
                }
            } else {
                print("📱 Credit System: ⚠️ User document not found in Firestore")
            }
        } catch {
            print("📱 Credit System: Error verifying Firestore credits: \(error)")
        }
    }
    
    /// Reset the initial credits flag (call when user signs out or session changes)
    func resetInitialCreditsFlag() {
        initialCreditsSet = false
        print("📱 Credit System: Initial credits flag reset")
    }
    
    func saveCredits() {
        UserDefaults.standard.set(credits, forKey: "userCredits")
    }
    
    func saveSubscriptionStatus() {
        UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed")
    }
    
    /// Save credits to Firestore (for new users)
    func saveCreditsToFirestore() async throws {
        guard let userId = firebaseManager.currentUser?.uid else {
            throw NSError(domain: "CreditSystem", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        print("📱 Credit System: 🔥 Saving \(credits) credits to Firestore for user \(userId)")
        
        let db = Firestore.firestore()
        try await db.collection("users").document(userId).setData([
            "credits": credits,
            "creditsUpdatedAt": Date(),
            "lastUpdated": Date()
        ], merge: true)
        
        print("📱 Credit System: ✅ Successfully saved \(credits) credits to Firestore for user \(userId)")
    }
    
    /// Force refresh credits from Firestore (useful when user signs back in)
    func refreshCreditsFromFirestore() async {
        print("📱 Credit System: Force refreshing credits from Firestore...")
        
        guard let userId = firebaseManager.currentUser?.uid else {
            print("📱 Credit System: ❌ Cannot refresh credits - no user ID")
            return
        }
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data()
                let firestoreCredits = userData?["credits"] as? Int ?? 0
                
                // Always sync with Firestore to ensure consistency
                if firestoreCredits != credits {
                    await MainActor.run {
                        credits = firestoreCredits
                    }
                    saveCredits() // Save to UserDefaults
                    print("📱 Credit System: Synced credits from Firestore: \(firestoreCredits)")
                } else {
                    print("📱 Credit System: Credits already consistent with Firestore: \(firestoreCredits)")
                }
            } else {
                print("📱 Credit System: User document does not exist in Firestore.")
            }
        } catch {
            print("📱 Credit System: ❌ Error refreshing credits from Firestore: \(error.localizedDescription)")
        }
    }
    
    /// Force refresh subscription status from Firestore (useful when user signs back in)
    func refreshSubscriptionStatusFromFirestore() async {
        print("📱 Subscription System: Force refreshing subscription status from Firestore...")
        
        guard let userId = firebaseManager.currentUser?.uid else {
            print("📱 Subscription System: ❌ Cannot refresh subscription status - no user ID")
            return
        }
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data()
                let firestoreIsSubscribed = userData?["isSubscribed"] as? Bool ?? false
                
                // Always sync with Firestore to ensure consistency
                if firestoreIsSubscribed != isSubscribed {
                    await MainActor.run {
                        isSubscribed = firestoreIsSubscribed
                    }
                    saveSubscriptionStatus() // Save to UserDefaults
                    print("📱 Subscription System: Synced subscription status from Firestore: \(firestoreIsSubscribed)")
                } else {
                    print("📱 Subscription System: Subscription status already consistent with Firestore: \(firestoreIsSubscribed)")
                }
            } else {
                print("📱 Subscription System: User document does not exist in Firestore.")
                // If user doc doesn't exist, assume not subscribed
                await MainActor.run {
                    isSubscribed = false
                }
                saveSubscriptionStatus()
            }
        } catch {
            print("📱 Subscription System: ❌ Error refreshing subscription status from Firestore: \(error.localizedDescription)")
        }
    }
    
    /// Refresh admin status
    func refreshAdminStatus() async {
        // For now, just a placeholder - implement if needed
        print("📱 Admin: Refreshing admin status")
    }
    
    /// Clear only session-specific data (for logout) - preserves user credits and device tracking
    func clearSessionData() {
        // Only clear session-specific data, not persistent user data
        isSubscribed = false
        selectedModel = .gpt4oMini
        resetInitialCreditsFlag() // Reset the initial credits flag
        
        // Note: We DON'T reset credits here - they should persist across sessions
        // Note: We DON'T reset deviceFirstAccountCreditsAwarded here — preserves 3000 vs 50 for new accounts on this device
        
        print("📱 Admin: Session data cleared (credits and device tracking preserved)")
    }
        
    func updateSubscriptionStatus(_ isSubscribed: Bool) {
        self.isSubscribed = isSubscribed
        UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed")
    }
    
    func restorePurchases() async {
        // Implement restore purchases logic
        print("Restoring purchases...")
    }
    
    // MARK: - Admin Functions
    
    func toggleAdminPanel() {
        showAdminPanel.toggle()
    }
    
    func isAdmin() -> Bool {
        // Check if current user is admin (allow real owner email)
        let adminEmails: Set<String> = [
            "admin@adoreventure.com",
            "dagmawi.m.mulualem@gmail.com"
        ]
        guard let email = firebaseManager.currentUser?.email?.lowercased() else {
            return false
        }
        return adminEmails.contains(email)
    }
    
    // MARK: - Search and Model Management
    
    /// Check if user can perform search
    func canPerformSearch() async -> Bool {
        return credits > 0 && accountStatus == .active
    }
    
    /// Check if current user is the special tester account
    func isTesterAccount() -> Bool {
        guard let userEmail = firebaseManager.currentUser?.email else { return false }
        return userEmail.lowercased() == testerEmail.lowercased()
    }
    
    /// Get current AI model
    var currentModel: AIModel {
        return selectedModel
    }
    
    /// Get search limit message
    var searchLimitMessage: String {
        if isSubscribed {
            return "Unlimited searches"
        } else {
            return "\(credits) searches remaining"
        }
    }
    
    /// Get monthly searches used
    var monthlySearchesUsed: Int {
        // For now, return 0 - implement if needed
        return 0
    }
    
    /// Get current user effective limit
    var currentUserEffectiveLimit: Int {
        // For now, return a default limit - implement if needed
        return 100
    }
    
    /// Get last search date
    var lastSearchDate: Date? {
        // For now, return nil - implement if needed
        return nil
    }
    
    /// Record search usage
    func recordSearch(searchQuery: String) async {
        // Credit cost for search
        let creditsUsed = 50
        
        print("📱 Credit System: Recording search - Query: '\(searchQuery)', Credits to use: \(creditsUsed)")
        
        // Record search in Firestore first, then deduct credits only if successful
        do {
            guard let userId = firebaseManager.currentUser?.uid else {
                print("📱 Credit System: ❌ Cannot record search - no user ID")
                return
            }
            
            print("📱 Credit System: Recording search for user: \(userId)")
            
            let db = Firestore.firestore()
            
            let searchData: [String: Any] = [
                "userId": userId,
                "query": searchQuery,
                "creditsUsed": creditsUsed,
                "model": selectedModel.rawValue,
                "timestamp": Date()
            ]
            
            print("📱 Credit System: Search data to save: \(searchData)")
            
            try await db.collection("search_history").addDocument(data: searchData)
            print("📱 Credit System: ✅ Search successfully recorded in Firestore")
            
            // Only deduct credits AFTER successful Firestore save
            useCredits(creditsUsed)
            print("📱 Credit System: 💳 Credits deducted after successful Firestore save. Remaining: \(credits)")
            
        } catch {
            print("📱 Credit System: ❌ Error recording search: \(error)")
            print("📱 Credit System: Error details - Domain: \((error as NSError).domain), Code: \((error as NSError).code)")
            print("📱 Credit System: 🚫 Credits NOT deducted due to Firestore save failure")
            // Don't deduct credits if Firestore save fails
        }
    }
    
    /// Handle failed search - ensures no credits are deducted
    func handleFailedSearch(searchQuery: String, error: Error) async {
        print("📱 Credit System: 🚫 Search failed - Query: '\(searchQuery)', Error: \(error.localizedDescription)")
        print("📱 Credit System: 🚫 No credits deducted for failed search")
        
        // Record failed search attempt for analytics (but don't deduct credits)
        do {
            guard let userId = firebaseManager.currentUser?.uid else {
                print("📱 Credit System: ❌ Cannot record failed search - no user ID")
                return
            }
            
            let db = Firestore.firestore()
            
            let failedSearchData: [String: Any] = [
                "userId": userId,
                "query": searchQuery,
                "status": "failed",
                "error": error.localizedDescription,
                "model": selectedModel.rawValue,
                "timestamp": Date(),
                "creditsUsed": 0 // No credits used for failed searches
            ]
            
            try await db.collection("search_history").addDocument(data: failedSearchData)
            print("📱 Credit System: 📊 Failed search recorded for analytics (no credits deducted)")
            
        } catch {
            print("📱 Credit System: ❌ Error recording failed search: \(error)")
        }
    }
    
    // MARK: - Account Creation (Simplified)
    
    /// Clear all data (for logout)
    func clearAllData() {
        // Reset local state
        credits = 0
        isSubscribed = false
        selectedModel = .gpt4oMini
        resetInitialCreditsFlag() // Reset the initial credits flag
        
        // Note: We DON'T reset deviceFirstAccountCreditsAwarded here — same device should not get 3000 again for a 2nd account
        
        // Note: We DON'T reset tester credits - they will be restored when they sign back in
        // print("📱 Admin: Tester credits will be restored on next sign-in")
        
        print("📱 Admin: All data cleared")
    }
}
