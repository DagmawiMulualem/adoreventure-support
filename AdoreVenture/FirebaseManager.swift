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
import GoogleSignIn
import AuthenticationServices
import ObjectiveC

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookmarkedIdeas: [AVIdea] = []
    
    private let db = Firestore.firestore()
    let subscriptionManager = SubscriptionManager.shared
    
    private init() {
        print("🔥 Firebase: FirebaseManager initialized")
        // Firebase will be configured in the app delegate
        setupGoogleSignIn()
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
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("🔥 Firebase: Google Sign-In configured with client ID: \(clientId)")
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, username: String, password: String) async -> Bool {
        print("🔥 Firebase: Attempting sign up for \(email) with username: \(username)")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            // Create the user first
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("🔥 Firebase: User created successfully for \(email)")
            
            // Set the current user immediately after creation
            await MainActor.run {
                self.currentUser = result.user
                self.isAuthenticated = true
            }
            
            // Store user data including username in Firestore
            try await storeUserData(userId: result.user.uid, email: email, username: username)
            
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
    
    private func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .limit(to: 1)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            print("🔥 Firebase: Error checking username availability - \(error.localizedDescription)")
            // If we can't check due to permissions, assume username is available
            // This is a fallback for the initial sign-up process
            return false
        }
    }
    
    private func storeUserData(userId: String, email: String, username: String) async throws {
        let db = Firestore.firestore()
        
        let userData: [String: Any] = [
            "email": email,
            "username": username,
            "createdAt": FieldValue.serverTimestamp(),
            "isSubscribed": false
        ]
        
        try await db.collection("users").document(userId).setData(userData)
        print("🔥 Firebase: User data stored successfully for \(username)")
    }
    
    func signIn(email: String, password: String) async -> Bool {
        print("🔥 Firebase: Attempting sign in for \(email)")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("🔥 Firebase: Sign in successful for \(email)")
            await MainActor.run {
                self.currentUser = result.user
                self.isAuthenticated = true
                self.isLoading = false
            }
            // Load bookmarks after successful sign in
            await loadBookmarks()
            return true
        } catch {
            print("🔥 Firebase: Sign in failed - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    func signInWithUsername(username: String, password: String) async -> Bool {
        print("🔥 Firebase: Attempting sign in with username: \(username)")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            // First, look up the email associated with the username
            let email = try await lookupEmailForUsername(username)
            if let email = email {
                // Sign in with the email
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                print("🔥 Firebase: Sign in successful for username: \(username) (email: \(email))")
                await MainActor.run {
                    self.currentUser = result.user
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                // Load bookmarks after successful sign in
                await loadBookmarks()
                return true
            } else {
                print("🔥 Firebase: Username not found: \(username)")
                await MainActor.run {
                    self.errorMessage = "Username not found. Please check your username or try signing in with email."
                    self.isLoading = false
                }
                return false
            }
        } catch {
            print("🔥 Firebase: Username sign in failed - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    private func lookupEmailForUsername(_ username: String) async throws -> String? {
        let db = Firestore.firestore()
        
        // Query the users collection to find the email for the given username
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        
        if let document = snapshot.documents.first {
            return document.data()["email"] as? String
        }
        
        return nil
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
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        print("🔥 Firebase: UserDefaults cleared")
        
        // Also clear subscription data
        subscriptionManager.clearAllData()
    }
    
    func resetPassword(email: String) async -> Bool {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            await MainActor.run {
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() async -> Bool {
        print("🔥 Firebase: Starting Google Sign-In...")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await MainActor.run {
                self.errorMessage = "Unable to present sign-in view"
                self.isLoading = false
            }
            return false
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    self.errorMessage = "Failed to get ID token from Google"
                    self.isLoading = false
                }
                return false
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("🔥 Firebase: Google Sign-In successful for \(authResult.user.email ?? "unknown")")
            await MainActor.run {
                self.currentUser = authResult.user
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            // Load bookmarks after successful sign in
            await loadBookmarks()
            return true
            
        } catch {
            print("🔥 Firebase: Google Sign-In failed - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple() async -> Bool {
        print("🔥 Firebase: Starting Apple Sign-In...")
        await MainActor.run { isLoading = true; errorMessage = nil }
        
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
            
            // If this is a new user, store their data
            if appleIDCredential.fullName != nil {
                let fullName = appleIDCredential.fullName!
                let username = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !username.isEmpty {
                    try await storeUserData(
                        userId: authResult.user.uid,
                        email: authResult.user.email ?? "",
                        username: username
                    )
                }
            }
            
            await MainActor.run {
                self.currentUser = authResult.user
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            // Load bookmarks after successful sign in
            await loadBookmarks()
            return true
            
        } catch {
            print("🔥 Firebase: Apple Sign-In failed - \(error.localizedDescription)")
            
            // Provide more specific error messages for common issues
            let errorMessage: String
            if error.localizedDescription.contains("cancelled") || error.localizedDescription.contains("canceled") {
                errorMessage = "Sign-In was cancelled"
            } else if error.localizedDescription.contains("not available") {
                errorMessage = "Apple Sign-In is not available on this device"
            } else if error.localizedDescription.contains("network") {
                errorMessage = "Network error. Please check your connection and try again"
            } else if error.localizedDescription.contains("token") {
                errorMessage = "Failed to get Apple ID token. Please try again"
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
    
    func checkAuthState() {
        print("🔥 Firebase: Checking auth state...")
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                print("🔥 Firebase: Auth state changed - User: \(user?.email ?? "nil")")
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                // Load bookmarks if user is authenticated
                if user != nil {
                    Task {
                        await self?.loadBookmarks()
                    }
                } else {
                    self?.bookmarkedIdeas = []
                }
            }
        }
    }
    
    func getCurrentUserEmail() -> String {
        return currentUser?.email ?? ""
    }
    
    func getCurrentUsername() -> String {
        // Return email prefix as fallback
        return currentUser?.email?.components(separatedBy: "@").first ?? "User"
    }
    
    // MARK: - Username Management
    
    @MainActor
    func fetchUsername() async -> String {
        guard let userId = currentUser?.uid else { return "User" }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data(), let username = data["username"] as? String {
                return username
            }
        } catch {
            print("🔥 Firebase: Error fetching username - \(error.localizedDescription)")
        }
        
        // Fallback to email prefix
        return currentUser?.email?.components(separatedBy: "@").first ?? "User"
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
