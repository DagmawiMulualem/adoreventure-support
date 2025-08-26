//
//  AdoreVentureApp.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import Firebase

@main
struct AdoreVentureApp: App {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var stripePaymentService = StripePaymentService.shared
    
    init() {
        print("🔥 Firebase: Configuring Firebase...")
        FirebaseApp.configure()
        print("🔥 Firebase: Firebase configured successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if firebaseManager.isAuthenticated {
                    ContentView()
                        .environmentObject(firebaseManager)
                        .environmentObject(firebaseManager.subscriptionManager)
                        .environmentObject(stripePaymentService)
                } else {
                    LoginView()
                        .environmentObject(firebaseManager)
                        .environmentObject(firebaseManager.subscriptionManager)
                        .environmentObject(stripePaymentService)
                }
            }
            .onAppear {
                firebaseManager.checkAuthState()
            }
        }
    }
}
