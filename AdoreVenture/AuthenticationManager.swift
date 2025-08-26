//
//  AuthenticationManager.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: String = ""
    
    // Sample credentials
    private var sampleCredentials = [
        "admin": "admin",
        "user": "password",
        "demo": "demo123"
    ]
    
    func login(email: String, password: String) -> Bool {
        // Check if credentials match our sample data
        if let storedPassword = sampleCredentials[email.lowercased()], storedPassword == password {
            isAuthenticated = true
            currentUser = email
            return true
        }
        return false
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = ""
    }
    
    func signUp(email: String, password: String) -> Bool {
        // For demo purposes, we'll add new credentials to our sample data
        // In a real app, this would save to a database
        let emailLower = email.lowercased()
        if !sampleCredentials.keys.contains(emailLower) {
            // Add new user to our sample credentials
            sampleCredentials[emailLower] = password
            isAuthenticated = true
            currentUser = email
            return true
        }
        return false
    }
}
