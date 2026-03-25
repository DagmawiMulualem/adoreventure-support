//
//  FirebaseManager.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import GoogleSignIn
import AuthenticationServices
import ObjectiveC

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var isAuthenticated = false {
        didSet {
            print("🔍 FirebaseManager: isAuthenticated changed from \(oldValue) to \(isAuthenticated)")
            objectWillChange.send()
        }
    }
    
    @Published var currentUser: User? {
        didSet {
            print("🔍 FirebaseManager: currentUser changed from \(oldValue?.uid ?? "nil") to \(currentUser?.uid ?? "nil")")
            objectWillChange.send()
        }
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookmarkedIdeas: [AVIdea] = []
    @Published var isSigningIn = false // Track when we're in the middle of sign-in
    @Published var currentDisplayName: String = "User" // Added for UI binding
    
    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?
    private var didStartAuthListener = false
    
    // Make subscriptionManager lazy to avoid circular dependency
    lazy var subscriptionManager: SubscriptionManager = {
        return SubscriptionManager.shared
    }()
    
    private init() {
        print("🔥 Firebase: FirebaseManager initialized")
        // Firebase will be configured in the app delegate
        setupGoogleSignIn()
        startAuthListenerIfNeeded()
    }
    
    private func setupGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("🔥 Firebase: GoogleService-Info.plist not found")
            return
        }
        
        guard let plist = NSDictionary(contentsOfFile: path) else {
            print("🔥 Firebase: Could not read GoogleService-Info.plist")
            return
        }
        
        guard let clientId = plist["CLIENT_ID"] as? String, !clientId.isEmpty else {
            print("🔥 Firebase: CLIENT_ID missing or empty in GoogleService-Info.plist")
            return
        }
        
        // Configure Google Sign-In
        let configuration = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = configuration
        
        print("🔥 Firebase: Google Sign-In configured with client ID: \(clientId)")
        
        // Restore previous Google Sign-In state if available
        restoreGoogleSignInState()
    }
    
    // MARK: - Auth Listener Management
    
    /// Start exactly one auth listener
    private func startAuthListenerIfNeeded() {
        guard !didStartAuthListener else { return }
        didStartAuthListener = true
        
        // 1) Set immediate state synchronously
        let user = Auth.auth().currentUser
        self.currentUser = user
        if user == nil {
            self.isAuthenticated = false
        } else {
            // User is authenticated
            self.isAuthenticated = true
            Task { await self.refreshPostLoginState() }
        }
        
        // 2) Register ONE listener
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                print("🔥 Firebase: Auth listener triggered - user: \(user?.uid ?? "nil"), isSigningIn: \(self.isSigningIn)")
                
                // Only update if we're not in the middle of sign-in to avoid conflicts
                if !self.isSigningIn {
                    // Always update currentUser
                    self.currentUser = user
                    
                    if let _ = user {
                        // User signed in → complete authentication
                        print("🔥 Firebase: Auth listener - User signed in")
                        Task { await self.refreshPostLoginState() }
                    } else {
                        // Signed out
                        self.isAuthenticated = false
                        print("🔥 Firebase: Auth listener - User signed out")
                        
                        // Force UI update
                        self.objectWillChange.send()
                    }
                } else {
                    print("🔥 Firebase: Auth listener - Sign-in in progress, skipping to avoid conflicts")
                }
            }
        }
    }
    
    /// Do the post-login loads in one place
    private func refreshPostLoginState() async {
        guard let _ = Auth.auth().currentUser else { return }
        
        // User is authenticated - complete authentication
        await MainActor.run {
            self.isAuthenticated = true
            print("🔥 Firebase: refreshPostLoginState - User authenticated")
            
            // Force UI update to ensure state changes are reflected immediately
            self.objectWillChange.send()
        }
        
        // Kick off background loads
        await self.subscriptionManager.checkAndSetInitialCredits()
        await self.subscriptionManager.refreshSubscriptionStatusFromFirestore()
        await self.loadBookmarks()
        await self.subscriptionManager.refreshAdminStatus()
        
        // Initialize display name
        let displayName = await self.fetchDisplayName()
        await MainActor.run {
            self.currentDisplayName = displayName
        }
    }
    
    // MARK: - Authentication Methods
    
        func signUp(email: String, displayName: String, password: String) async -> Bool {
        print("🔥 Firebase: Attempting sign up for \(email) with display name: \(displayName)")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            // Create the user first
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("🔥 Firebase: User created successfully for \(email)")
            
            // Set the current user immediately after creation
            // Update state directly on main actor (class is already @MainActor)
            self.currentUser = result.user
            self.isAuthenticated = true
            
            // Force immediate UI update to transition to main page
            self.objectWillChange.send()
            print("🔥 Firebase: Sign-up authentication state updated - forcing UI refresh")
            
            // Additional force refresh to ensure UI updates
            DispatchQueue.main.async {
                self.forceUIRefresh()
            }
            
            // CRITICAL: Check for new users and set initial credits BEFORE storing user data
            // This prevents the race condition where new users appear as existing users
            await subscriptionManager.recordNewAccountCreation(email: email, userId: result.user.uid)
            await subscriptionManager.checkAndSetInitialCredits()
            
            // Store user data including display name in Firestore AFTER credit system setup
            try await storeUserData(userId: result.user.uid, email: email, displayName: displayName)
            
            // Force refresh credits from Firestore to ensure accuracy after sign-up
            await subscriptionManager.refreshCreditsFromFirestore()
            
            // Initialize display name
            await MainActor.run {
                self.currentDisplayName = displayName
            }
            
            await MainActor.run {
                self.isLoading = false
            }
            return true
        } catch {
            print("🔥 Firebase: Sign up failed - \(error.localizedDescription)")
            
            // Provide more specific error messages
            let errorMessage: String
            if error.localizedDescription.contains("email") {
                errorMessage = "This email is already in use. Please try a different email or sign in instead."
            } else if error.localizedDescription.contains("password") {
                errorMessage = "Password is too weak. Please use at least 6 characters."
            } else if error.localizedDescription.contains("permission") {
                errorMessage = "Account creation failed due to permissions. Please try again."
            } else {
                errorMessage = error.localizedDescription
            }
            
            await MainActor.run {
                self.errorMessage = errorMessage
                self.isLoading = false
            }
            return false
        }
    }
    
    private func storeUserData(userId: String, email: String, displayName: String) async throws {
        // Store user data directly in Firestore
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "createdAt": FieldValue.serverTimestamp(),
            "isSubscribed": false
        ]
        
        try await db.collection("users").document(userId).setData(userData, merge: true)
        print("🔥 Firebase: User data stored successfully for \(displayName)")
    }
    
    func signIn(email: String, password: String) async -> Bool {
        print("🔥 Firebase: Attempting sign in for \(email)")
        print("🔥 Firebase: Current auth state - isAuthenticated: \(isAuthenticated), currentUser: \(currentUser?.uid ?? "nil")")
        await MainActor.run { isLoading = true; errorMessage = nil }
        

        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("🔥 Firebase: Sign in successful for \(email)")
            print("🔥 Firebase: Firebase Auth user ID: \(result.user.uid)")
            
            // Set authentication state immediately (class is already @MainActor)
            self.currentUser = result.user
            self.isAuthenticated = true
            self.isLoading = false
            
            // Force immediate UI update to transition to main page
            self.objectWillChange.send()
            print("🔥 Firebase: Authentication state updated - forcing UI refresh - isAuthenticated: \(self.isAuthenticated), currentUser: \(self.currentUser?.uid ?? "nil")")
            
            // Additional force refresh to ensure UI updates
            DispatchQueue.main.async {
                self.forceUIRefresh()
            }
            
            // Load bookmarks after successful sign in
            await loadBookmarks()
            // Refresh admin status after successful sign in
            await subscriptionManager.refreshAdminStatus()
            
            // Initialize display name
            let displayName = await self.fetchDisplayName()
            self.currentDisplayName = displayName
            
            print("🔥 Firebase: Sign in completed successfully")
            return true
        } catch {
            print("🔥 Firebase: Sign in failed - \(error.localizedDescription)")
            print("🔥 Firebase: Error details - Domain: \((error as NSError).domain), Code: \((error as NSError).code)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    func signOut() {
        do {
            print("🔥 Firebase: Signing out user...")
            

            
            // Sign out from Firebase Auth
            try Auth.auth().signOut()
            
            // Sign out from Google if signed in
            if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                GIDSignIn.sharedInstance.signOut()
                print("🔥 Firebase: Signed out from Google")
            }
            
            // Clear all cached data
            currentUser = nil
            isAuthenticated = false
            bookmarkedIdeas = []
            errorMessage = nil
            isLoading = false
            
            // Clear UserDefaults
            clearUserDefaults()
            
            print("🔥 Firebase: Sign out completed successfully")
        } catch {
            print("🔥 Firebase: Sign out error - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Preserve important user data that should persist across sessions
        let preservedCredits = defaults.object(forKey: "userCredits") as? Int ?? 0
        /// Ensures 3000 vs 50 onboarding split stays correct when adding another account on this device.
        let preservedFirstAccountOnDevice = defaults.bool(forKey: "deviceFirstAccountCreditsAwarded")
        let preservedSubscriptionStatus = defaults.string(forKey: "subscriptionStatus")
        
        // Clear all UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        print("🔥 Firebase: UserDefaults cleared")
        
        // Restore preserved data
        defaults.set(preservedCredits, forKey: "userCredits")
        defaults.set(preservedFirstAccountOnDevice, forKey: "deviceFirstAccountCreditsAwarded")
        if let subscriptionStatus = preservedSubscriptionStatus {
            defaults.set(subscriptionStatus, forKey: "subscriptionStatus")
        }
        
        print("🔥 Firebase: Preserved user credits: \(preservedCredits), first-account-on-device flag: \(preservedFirstAccountOnDevice)")
        
        // Clear session-specific data only (not persistent user data)
        subscriptionManager.clearSessionData()
    }
    
    func resetPassword(email: String) async -> Bool {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            // First try the standard Firebase password reset
            try await Auth.auth().sendPasswordReset(withEmail: email)
            
            await MainActor.run {
                self.isLoading = false
            }
            return true
        } catch {
            print("🔥 Firebase: Standard password reset failed, trying custom method")
            
            // If standard method fails, try custom method
            do {
                _ = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                    try await Functions.functions(region: "us-central1").httpsCallable("sendCustomPasswordReset").call([
                        "email": email
                    ]).data
                }
                
                await MainActor.run {
                    self.isLoading = false
                }
                return true
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to send password reset email. Please try again or contact support."
                    self.isLoading = false
                }
                return false
            }
        }
    }
    
    // MARK: - Google Sign-In
    
    @MainActor
    func signInWithGoogle() async -> Bool {
        print("🔥 Firebase: Starting Google Sign-In...")
        
        // Clear any previous errors
        errorMessage = nil
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            self.errorMessage = "Unable to present sign-in view. Please try again."
            self.isLoading = false
            return false
        }
        
        // Ensure we're on the main thread for UI operations
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.isSigningIn = true // Mark that we're signing in
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                self.errorMessage = "Failed to get ID token from Google"
                self.isLoading = false
                return false
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("🔥 Firebase: Google Sign-In successful for \(authResult.user.email ?? "unknown")")
            
            // Update state directly on main actor (class is already @MainActor)
            self.currentUser = authResult.user
            self.isLoading = false
            self.isAuthenticated = true
            
            // Force immediate UI update to transition to main page
            self.objectWillChange.send()
            print("🔥 Firebase: Google Sign-In authentication complete - forcing UI refresh")
            
            // Additional force refresh to ensure UI updates
            DispatchQueue.main.async {
                self.forceUIRefresh()
            }
            
            // Check if this is a new user and record account creation if needed
            let isNewUser = await checkIfNewUser(userId: authResult.user.uid)
            if isNewUser {
                print("🔥 Firebase: New Google user detected, recording account creation")
                await subscriptionManager.recordNewAccountCreation(
                    email: authResult.user.email ?? "",
                    userId: authResult.user.uid
                )
            }
            
            // Check and set initial credits for new users
            await subscriptionManager.checkAndSetInitialCredits()
            
            // Force refresh credits from Firestore to ensure accuracy after sign-in
            await subscriptionManager.refreshCreditsFromFirestore()
            // Force refresh subscription status from Firestore to ensure accuracy after sign-in
            await subscriptionManager.refreshSubscriptionStatusFromFirestore()
            
            // Load bookmarks after successful sign in
            await loadBookmarks()
            // Refresh admin status after successful sign in
            await subscriptionManager.refreshAdminStatus()
            
            // Force UI update by triggering state change
            await MainActor.run {
                // This will trigger the UI to re-evaluate the authentication state
                self.objectWillChange.send()
                print("🔥 Firebase: UI update triggered")
            }
            
            // Clear the signing-in flag
            await MainActor.run {
                self.isSigningIn = false
            }
            
            return true
            
        } catch {
            print("🔥 Firebase: Google Sign-In failed - \(error.localizedDescription)")
            
            // Check if this is a user cancellation or common non-error scenarios
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("canceled") || 
               errorMessage.contains("cancelled") ||
               errorMessage.contains("user_cancel") ||
               errorMessage.contains("popover") ||
               errorMessage.contains("presentation") {
                print("🔥 Firebase: User canceled Google Sign-In or presentation issue - not showing error")
                self.errorMessage = nil
                self.isLoading = false
                self.isSigningIn = false // Clear the flag
                return false
            }
            
            // This is a real error - show it to the user
            let userFriendlyMessage = ErrorDisplayHelper.getErrorMessage(error)
            
            // Provide more specific error messages for common Google Sign-In issues
            if errorMessage.contains("network") || errorMessage.contains("connection") {
                self.errorMessage = "Network connection issue. Please check your internet connection and try again."
            } else if errorMessage.contains("configuration") || errorMessage.contains("client") {
                self.errorMessage = "Google Sign-In configuration issue. Please try again later."
            } else {
                self.errorMessage = userFriendlyMessage
            }
            
            self.isLoading = false
            self.isSigningIn = false // Clear the flag
            return false
        }
    }
    
    // MARK: - Google Sign-In State Management
    
    /// Restore Google Sign-In state if user was previously signed in
    func restoreGoogleSignInState() {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            print("🔥 Firebase: Restoring previous Google Sign-In state...")
            Task {
                do {
                    let result = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                    print("🔥 Firebase: Previous Google Sign-In restored for \(result.userID ?? "unknown")")
                } catch {
                    print("🔥 Firebase: Failed to restore previous Google Sign-In: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Sign out from Google Sign-In (useful for troubleshooting)
    func signOutFromGoogle() {
        GIDSignIn.sharedInstance.signOut()
        print("🔥 Firebase: Signed out from Google Sign-In")
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple() async -> Bool {
        print("🔥 Firebase: Starting Apple Sign-In...")
        await MainActor.run { 
            isLoading = true; 
            errorMessage = nil 
            isSigningIn = true // Mark that we're signing in
        }
        
        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let result = try await withCheckedThrowingContinuation { continuation in
                let controller = ASAuthorizationController(authorizationRequests: [request])
                let delegate = AppleSignInDelegate { result in
                    continuation.resume(with: result)
                }
                controller.delegate = delegate
                controller.presentationContextProvider = delegate
                controller.performRequests()
                
                // Store delegate to prevent deallocation
                objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            }
            
            print("🔥 Firebase: Authorization result type: \(type(of: result))")
            
            // The result should be ASAuthorization, we need to get the credential from it
            guard let authorization = result as? ASAuthorization else {
                print("🔥 Firebase: Result is not ASAuthorization")
                await MainActor.run {
                    self.errorMessage = "Invalid authorization result"
                    self.isLoading = false
                }
                return false
            }
            
            // Get the Apple ID credential from the authorization
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("🔥 Firebase: Failed to get Apple ID credential from authorization")
                print("🔥 Firebase: Credential type: \(type(of: authorization.credential))")
                
                // Try to handle other credential types
                if let passwordCredential = authorization.credential as? ASPasswordCredential {
                    print("🔥 Firebase: Got password credential instead of Apple ID credential")
                    await MainActor.run {
                        self.errorMessage = "Please use Apple ID Sign-In, not password"
                        self.isLoading = false
                    }
                    return false
                }
                
                await MainActor.run {
                    self.errorMessage = "Unexpected credential type. Please try again."
                    self.isLoading = false
                }
                return false
            }
            
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("🔥 Firebase: Apple ID token is nil or cannot be converted to string")
                await MainActor.run {
                    self.errorMessage = "Failed to get Apple ID token"
                    self.isLoading = false
                }
                return false
            }
            
            print("🔥 Firebase: Got Apple ID token successfully")
            
            // Create Firebase credential
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: "",
                fullName: appleIDCredential.fullName
            )
            
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("🔥 Firebase: Apple Sign-In successful for \(authResult.user.email ?? "unknown")")
            
            // If this is a new user, store their display name
            if appleIDCredential.fullName != nil {
                let fullName = appleIDCredential.fullName!
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !displayName.isEmpty {
                    try await storeUserData(
                        userId: authResult.user.uid,
                        email: authResult.user.email ?? "",
                        displayName: displayName
                    )
                }
            }
            
            // Update state directly on main actor (class is already @MainActor)
            self.currentUser = authResult.user
            self.isLoading = false
            self.isAuthenticated = true
            print("🔥 Firebase: Apple Sign-In authentication complete")
            
            // Force immediate UI update
            self.objectWillChange.send()
            
            // Additional force refresh to ensure UI updates
            DispatchQueue.main.async {
                self.forceUIRefresh()
            }
            
            // Emergency auth state fix
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.emergencyAuthStateFix()
            }
            
            // Check if this is a new user and record account creation if needed
            let isNewUser = await checkIfNewUser(userId: authResult.user.uid)
            if isNewUser {
                print("🔥 Firebase: New Apple user detected, recording account creation")
                await subscriptionManager.recordNewAccountCreation(
                    email: authResult.user.email ?? "",
                    userId: authResult.user.uid
                )
            }
            
            // Check and set initial credits for new users
            await subscriptionManager.checkAndSetInitialCredits()
            
            // Force refresh credits from Firestore to ensure accuracy after sign-in
            await subscriptionManager.refreshCreditsFromFirestore()
            // Force refresh subscription status from Firestore to ensure accuracy after sign-in
            await subscriptionManager.refreshSubscriptionStatusFromFirestore()
            
            // Load bookmarks after successful sign in
            await loadBookmarks()
            // Refresh admin status after successful sign in
            await subscriptionManager.refreshAdminStatus()
            
            // Initialize display name
            let displayName = await self.fetchDisplayName()
            self.currentDisplayName = displayName
            
            // Force UI update by triggering state change
            self.objectWillChange.send()
            print("🔥 Firebase: UI update triggered")
            
            // Clear the signing-in flag
            self.isSigningIn = false
            
            return true
            
        } catch {
            print("🔥 Firebase: Apple Sign-In failed - \(error.localizedDescription)")
            
            await MainActor.run {
                self.errorMessage = ErrorDisplayHelper.getErrorMessage(error)
                self.isLoading = false
                self.isSigningIn = false // Clear the flag
            }
            return false
        }
    }
    
    func checkAuthState() {
        startAuthListenerIfNeeded()
        
        // Also check current Firebase Auth state
        let currentUser = Auth.auth().currentUser
        print("🔍 Debug: checkAuthState - Firebase Auth currentUser: \(currentUser?.uid ?? "nil")")
        print("🔍 Debug: checkAuthState - Local isAuthenticated: \(isAuthenticated)")
        print("🔍 Debug: checkAuthState - Local currentUser: \(self.currentUser?.uid ?? "nil")")
        
        // If there's a mismatch, fix it
        if let firebaseUser = currentUser, !isAuthenticated {
            print("🔍 Debug: checkAuthState - Fixing authentication state mismatch")
            self.currentUser = firebaseUser
            self.isAuthenticated = true
            self.objectWillChange.send()
            print("🔍 Debug: checkAuthState - Fixed auth state, forcing UI update")
            Task { await self.refreshPostLoginState() }
        } else if currentUser == nil && isAuthenticated {
            print("🔍 Debug: checkAuthState - Fixing authentication state mismatch (signed out)")
            self.currentUser = nil
            self.isAuthenticated = false
            self.objectWillChange.send()
            print("🔍 Debug: checkAuthState - Fixed sign-out state, forcing UI update")
        }
    }
    
    /// Force a UI refresh by triggering state change
    func forceUIRefresh() {
        print("🔄 Force UI refresh triggered")
        self.objectWillChange.send()
        
        // Additional aggressive refresh approach
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.objectWillChange.send()
            print("🔄 Delayed UI refresh triggered")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.objectWillChange.send()
            print("🔄 Final delayed UI refresh triggered")
        }
        
        // Continuous refresh for the next few seconds
        var refreshCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            refreshCount += 1
            if refreshCount <= 15 { // Refresh for 3 seconds
                self.objectWillChange.send()
                print("🔄 Continuous UI refresh \(refreshCount)/15")
            } else {
                timer.invalidate()
                print("🔄 Continuous UI refresh completed")
            }
        }
    }
    
    /// Emergency authentication state fix
    func emergencyAuthStateFix() {
        print("🚨 Emergency auth state fix triggered")
        
        // Check Firebase Auth state
        let firebaseUser = Auth.auth().currentUser
        print("🚨 Emergency: Firebase Auth user: \(firebaseUser?.uid ?? "nil")")
        print("🚨 Emergency: Local isAuthenticated: \(isAuthenticated)")
        print("🚨 Emergency: Local currentUser: \(currentUser?.uid ?? "nil")")
        
        // Force sync with Firebase Auth
        if let user = firebaseUser {
            if !isAuthenticated || currentUser?.uid != user.uid {
                print("🚨 Emergency: Fixing authentication state")
                currentUser = user
                isAuthenticated = true
                objectWillChange.send()
                
                // Force multiple UI updates
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.objectWillChange.send()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.objectWillChange.send()
                }
            }
        } else {
            if isAuthenticated || currentUser != nil {
                print("🚨 Emergency: Fixing sign-out state")
                currentUser = nil
                isAuthenticated = false
                objectWillChange.send()
            }
        }
    }
    
    func getCurrentUserEmail() -> String {
        return currentUser?.email ?? ""
    }
    
    func getCurrentDisplayName() -> String {
        // Return email prefix as fallback
        return currentUser?.email?.components(separatedBy: "@").first ?? "User"
    }
    
    // MARK: - User Management
    
    /// Check if a user is new (doesn't exist in Firestore)
    private func checkIfNewUser(userId: String) async -> Bool {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            return !document.exists
        } catch {
            print("🔥 Firebase: Error checking if user is new: \(error)")
            return false
        }
    }
    
    // MARK: - Display Name Management
    
    @MainActor
    func fetchDisplayName() async -> String {
        guard let userId = currentUser?.uid else { return "User" }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data(), let displayName = data["displayName"] as? String, !displayName.isEmpty {
                // Update the published property
                self.currentDisplayName = displayName
                return displayName
            }
        } catch {
            print("🔥 Firebase: Error fetching display name - \(error.localizedDescription)")
        }
        
        // Fallback to email prefix
        let fallbackName = currentUser?.email?.components(separatedBy: "@").first ?? "User"
        self.currentDisplayName = fallbackName
        return fallbackName
    }
    
    func updateDisplayName(_ displayName: String) async -> Bool {
        print("🔥 Firebase: Updating display name: \(displayName)")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            guard let userId = currentUser?.uid else { return false }
            
            // Update display name in Firestore
            try await db.collection("users").document(userId).setData([
                "displayName": displayName,
                "lastUpdated": Date()
            ], merge: true)
            
            // Update the published property immediately
            await MainActor.run {
                self.currentDisplayName = displayName
            }
            
            print("🔥 Firebase: Display name updated successfully")
            await MainActor.run {
                self.isLoading = false
            }
            return true
            
        } catch {
            print("🔥 Firebase: Error updating display name - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = ErrorDisplayHelper.getErrorMessage(error)
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Bookmark Methods
    
    func toggleBookmark(for idea: AVIdea) async -> Bool {
        guard let userId = currentUser?.uid else {
            print("🔥 Firebase: No authenticated user for bookmark toggle")
            return false
        }
        
        let bookmarkId = "\(idea.title)_\(idea.place)".replacingOccurrences(of: " ", with: "_")
        
        do {
            let bookmarkRef = db.collection("users").document(userId).collection("bookmarks").document(bookmarkId)
            
            // Check if already bookmarked
            let document = try await bookmarkRef.getDocument()
            
            if document.exists {
                // Remove bookmark
                try await bookmarkRef.delete()
                await MainActor.run {
                    bookmarkedIdeas.removeAll { $0.id == idea.id }
                }
                print("🔥 Firebase: Bookmark removed for \(idea.title)")
                return false
            } else {
                // Add bookmark
                let bookmarkData: [String: Any] = [
                    "title": idea.title,
                    "blurb": idea.blurb,
                    "rating": idea.rating,
                    "place": idea.place,
                    "duration": idea.duration,
                    "priceRange": idea.priceRange,
                    "tags": idea.tags,
                    "address": idea.address ?? "",
                    "phone": idea.phone ?? "",
                    "website": idea.website ?? "",
                    "bookingURL": idea.bookingURL ?? "",
                    "bestTime": idea.bestTime ?? "",
                    "hours": idea.hours ?? [],
                    "bookmarkedAt": FieldValue.serverTimestamp()
                ]
                
                try await bookmarkRef.setData(bookmarkData)
                await MainActor.run {
                    bookmarkedIdeas.append(idea)
                }
                print("🔥 Firebase: Bookmark added for \(idea.title)")
                return true
            }
        } catch {
            print("🔥 Firebase: Error toggling bookmark - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to save bookmark: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func isBookmarked(_ idea: AVIdea) -> Bool {
        return bookmarkedIdeas.contains { $0.id == idea.id }
    }
    
    private func loadBookmarks() async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users").document(userId).collection("bookmarks").getDocuments()
            
            let ideas = snapshot.documents.compactMap { document -> AVIdea? in
                let data = document.data()
                
                return AVIdea(
                    title: data["title"] as? String ?? "",
                    blurb: data["blurb"] as? String ?? "",
                    rating: data["rating"] as? Double ?? 0.0,
                    place: data["place"] as? String ?? "",
                    duration: data["duration"] as? String ?? "",
                    priceRange: data["priceRange"] as? String ?? "",
                    tags: data["tags"] as? [String] ?? [],
                    address: data["address"] as? String,
                    phone: data["phone"] as? String,
                    website: data["website"] as? String,
                    bookingURL: data["bookingURL"] as? String,
                    bestTime: data["bestTime"] as? String,
                    hours: data["hours"] as? [String]
                )
            }
            
            await MainActor.run {
                self.bookmarkedIdeas = ideas
            }
            
            print("🔥 Firebase: Loaded \(ideas.count) bookmarks")
        } catch {
            print("🔥 Firebase: Error loading bookmarks - \(error.localizedDescription)")
            
            // Don't let bookmark loading errors prevent app from loading
            // Set empty bookmarks array to ensure app can proceed
            await MainActor.run {
                self.bookmarkedIdeas = []
            }
        }
    }
    

    

}

// MARK: - Apple Sign-In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign-In")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🔥 Firebase: Apple Sign-In authorization completed successfully")
        print("🔥 Firebase: Authorization type: \(type(of: authorization))")
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print("🔥 Firebase: Got Apple ID credential for user: \(appleIDCredential.user)")
            if let email = appleIDCredential.email {
                print("🔥 Firebase: User email: \(email)")
            }
        } else if let passwordCredential = authorization.credential as? ASPasswordCredential {
            print("🔥 Firebase: Got password credential for user: \(passwordCredential.user)")
        } else {
            print("🔥 Firebase: Got unknown credential type: \(type(of: authorization.credential))")
        }
        
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🔥 Firebase: Apple Sign-In authorization failed - \(error.localizedDescription)")
        completion(.failure(error))
    }
}


