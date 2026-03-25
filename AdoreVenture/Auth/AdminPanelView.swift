//
//  AdminPanelView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/24/25.
//

import SwiftUI
import FirebaseFunctions

struct AdminPanelView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchLimit = 16
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        HeaderView()
                        CurrentStatusView(subscriptionManager: subscriptionManager)
                        SubscriptionControlsView(subscriptionManager: subscriptionManager, showAlert: showAlert)
                        SearchControlsView(subscriptionManager: subscriptionManager, searchLimit: $searchLimit, showAlert: showAlert)
                        StripeTestControlsView(showAlert: showAlert)
                        GrantCreditsByEmailView(showAlert: showAlert)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .alert("Admin Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            searchLimit = subscriptionManager.currentUserEffectiveLimit
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
            
            Text("Admin Panel")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Debug and testing controls")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 20)
    }
}

// MARK: - Current Status View
struct CurrentStatusView: View {
    let subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Current Status")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                StatusRow(title: "Subscription", value: subscriptionManager.isSubscribed ? "Active" : "Inactive")
                StatusRow(title: "Monthly Searches Used", value: "\(subscriptionManager.monthlySearchesUsed)/\(subscriptionManager.currentUserEffectiveLimit)")
                StatusRow(title: "Last Search Date", value: subscriptionManager.lastSearchDate?.formatted() ?? "Never")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Subscription Controls View
struct SubscriptionControlsView: View {
    let subscriptionManager: SubscriptionManager
    let showAlert: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Subscription Controls")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        subscriptionManager.updateSubscriptionStatus(!subscriptionManager.isSubscribed)
                        showAlert("Subscription toggled to \(subscriptionManager.isSubscribed ? "Active" : "Inactive")")
                    }
                } label: {
                    HStack {
                        Image(systemName: subscriptionManager.isSubscribed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        Text(subscriptionManager.isSubscribed ? "Disable Subscription" : "Enable Subscription")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(subscriptionManager.isSubscribed ? .red : .green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(subscriptionManager.isLoading)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Search Controls View
struct SearchControlsView: View {
    let subscriptionManager: SubscriptionManager
    @Binding var searchLimit: Int
    let showAlert: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Search Controls")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        subscriptionManager.credits = 0
                        showAlert("Search count reset to 0")
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset Search Count")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(subscriptionManager.isLoading)
                
                Button {
                    Task {
                        subscriptionManager.credits += 1
                        showAlert("Search count incremented")
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Force Increment Search Count")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(subscriptionManager.isLoading)
                
                HStack {
                    Text("Custom Search Limit:")
                        .foregroundStyle(.white.opacity(0.8))
                    
                    TextField("Limit", value: $searchLimit, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accentColor(.white)
                    
                    Button {
                        Task {
                            subscriptionManager.credits = searchLimit
                            showAlert("Custom search limit set to \(searchLimit)")
                        }
                    } label: {
                        Text("Set Custom Search Limit")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(subscriptionManager.isLoading)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Stripe Test Controls View
struct StripeTestControlsView: View {
    let showAlert: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Stripe Test Controls")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        let success = await StripePaymentService.shared.testStripeConfiguration()
                        showAlert("Stripe config test: \(success ? "Success" : "Failed")")
                    }
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                        Text("Test Stripe Configuration")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Grant Credits by Email (Admin)
struct GrantCreditsByEmailView: View {
    let showAlert: (String) -> Void
    @State private var email = "Shiferawsara53@gmail.com"
    @State private var amount = 1000
    @State private var isGranting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Grant Credits to User")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                TextField("User email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .accentColor(.white)

                HStack {
                    Text("Amount:")
                        .foregroundStyle(.white.opacity(0.8))
                    TextField("Amount", value: $amount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .keyboardType(.numberPad)
                }

                Button {
                    Task {
                        await grantCredits()
                    }
                } label: {
                    HStack {
                        if isGranting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "gift")
                            Text("Grant \(amount) Credits")
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isGranting || email.isEmpty || amount <= 0)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func grantCredits() async {
        guard !isGranting else { return }
        isGranting = true
        defer { isGranting = false }
        do {
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await Functions.functions(region: "us-central1").httpsCallable("grantCreditsToUserByEmail").call([
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "amount": amount
                ]).data
            }
            guard let data = raw as? [String: Any],
                  let success = data["success"] as? Bool, success else {
                showAlert("Grant completed but response was unexpected.")
                return
            }
            let newCredits = (data["newCredits"] as? NSNumber)?.intValue ?? (data["newCredits"] as? Int) ?? 0
            showAlert("Granted \(amount) credits to \(email). New balance: \(newCredits)")
        } catch {
            let msg = (error as NSError).localizedDescription
            showAlert("Failed: \(msg)")
        }
    }
}

// MARK: - Status Row
struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}
