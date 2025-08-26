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
        RootView()
            .environmentObject(firebaseManager)
    }
}

#Preview {
    ContentView()
}

