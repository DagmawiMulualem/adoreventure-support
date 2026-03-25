//
//  ContentView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    
    var body: some View {
        Group {
            if firebaseManager.isAuthenticated {
                // Show main app when authenticated
                RootView()
                    .environmentObject(firebaseManager)
            } else {
                // Show login view when not authenticated
                LoginView()
                    .environmentObject(firebaseManager)
            }
        }
    }
}

#Preview {
    ContentView()
}

