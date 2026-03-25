//
//  AdoreVentureApp.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import Firebase
import StripePaymentSheet
import StripeApplePay
import PassKit
import UIKit

// MARK: - App Delegate for Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🔥 Firebase: Configuring Firebase...")
        FirebaseApp.configure()
        print("🔥 Firebase: Firebase configured successfully")
        
        print("💳 Stripe: Configuring Stripe...")
        // Configure Stripe with your LIVE publishable key
        StripeAPI.defaultPublishableKey = "pk_live_51S0M4Y2L7M9M7pXjLjiYWykj8nL682f12GLZ92qqrO3hqALZLSD5OnUjoH1Or95srCkwC7r8YEaxmTKZokQjypli00oMRjD58b"
        print("💳 Stripe: Stripe configured successfully")
        
        print("🍎 Apple Pay: Apple Pay is ready to use...")
        // Apple Pay is configured through the StripePaymentService
        // The merchant identifier is set in the payment requests
        print("🍎 Apple Pay: Apple Pay configured successfully")
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Stripe redirect URLs
        let stripeHandled = StripeAPI.handleURLCallback(with: url)
        if !stripeHandled {
            // Handle other custom URL schemes if needed
            print("Received non-Stripe URL: \(url)")
        }
        return stripeHandled
    }
}

@main
struct AdoreVentureApp: App {
    // Register the app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Use StateObject to ensure proper observation of FirebaseManager
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var stripePaymentService = StripePaymentService.shared
    
    // Track app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            
            ZStack {
                if firebaseManager.isAuthenticated {
                    ContentView()
                        .environmentObject(firebaseManager)
                        .environmentObject(firebaseManager.subscriptionManager)
                        .environmentObject(stripePaymentService)
                        .onAppear {
                            print("📱 App: Showing ContentView - User authenticated")
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: firebaseManager.isAuthenticated)
                } else {
                    LoginView()
                        .environmentObject(firebaseManager)
                        .environmentObject(firebaseManager.subscriptionManager)
                        .environmentObject(stripePaymentService)
                        .onAppear {
                            print("📱 App: Showing LoginView - User not authenticated")
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: firebaseManager.isAuthenticated)
                }
            }
            .onAppear {
                let authState = "isAuthenticated: \(firebaseManager.isAuthenticated)"
                print("📱 App: Current auth state - \(authState)")
                
                // Ensure auth listener is started (idempotent)
                firebaseManager.checkAuthState()
                

            }
            .onChange(of: firebaseManager.isAuthenticated) { oldValue, newValue in
                print("📱 App: Authentication state changed from \(oldValue) to \(newValue)")
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Handle app lifecycle changes
                if newPhase == .active && firebaseManager.isAuthenticated {
                    // App became active - refresh data from Firebase
                    Task {
                        await firebaseManager.subscriptionManager.refreshCreditsFromFirestore()
                        await firebaseManager.subscriptionManager.refreshSubscriptionStatusFromFirestore()
                    }
                }
            }

        }
    }
}
