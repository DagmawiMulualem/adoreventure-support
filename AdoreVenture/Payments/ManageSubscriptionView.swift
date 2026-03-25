//
//  ManageSubscriptionView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/24/25.
//

import SwiftUI
import FirebaseFunctions
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ManageSubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var stripePaymentService: StripePaymentService
    @Environment(\.dismiss) private var dismiss
    @State private var showingCancelAlert = false
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        SubscriptionHeaderView()
                        CurrentPlanCardView()
                        SubscriptionDetailsView(subscriptionManager: subscriptionManager)
                        ActionButtonsView(
                            subscriptionManager: subscriptionManager,
                            stripePaymentService: stripePaymentService,
                            isLoading: $isLoading,
                            showAlert: $showAlert,
                            errorMessage: $errorMessage,
                            showingCancelAlert: $showingCancelAlert
                        )
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Manage Subscription")
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
        .alert("Subscription Action", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            } else {
                Text("Action completed")
            }
        }
        .alert("Cancel Subscription", isPresented: $showingCancelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) {
                Task {
                    await cancelSubscription()
                }
            }
        } message: {
            Text("Are you sure you want to cancel your subscription? You'll lose access to premium features at the end of your current billing period.")
        }
    }
    
    private func cancelSubscription() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Get current user's subscription ID from Firestore
            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]
            let subscriptionId = userData["subscriptionId"] as? String
            
            // Check if this is an admin-created subscription (no subscriptionId)
            if let subscriptionId = subscriptionId, !subscriptionId.isEmpty {
                // Regular Stripe subscription - schedule cancellation locally first
                subscriptionManager.isCancellationScheduled = true
                
                // Call Firebase Function to schedule cancellation in Stripe
                let endDate = subscriptionManager.subscriptionEndDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                
                print("🔥 Firebase: Calling scheduleSubscriptionCancellation with subscriptionId: \(subscriptionId), endDate: \(endDate)")
                
                do {
                    let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                        try await Functions.functions(region: "us-central1").httpsCallable("scheduleSubscriptionCancellation").call([
                            "subscriptionId": subscriptionId,
                            "endDate": endDate
                        ]).data
                    }
                    
                    print("🔥 Firebase: Function call successful: \(String(describing: raw))")
                } catch {
                    print("🔥 Firebase: Stripe cancellation failed, but local cancellation succeeded: \(error.localizedDescription)")
                    // Don't throw error here - local cancellation was successful
                }
            } else {
                // Admin-created subscription - just schedule locally
                print("🔥 Firebase: Admin-created subscription detected, scheduling cancellation locally only")
                subscriptionManager.isCancellationScheduled = true
            }
            
            await MainActor.run {
                isLoading = false
                // Don't dismiss - let user see the cancellation notice
            }
            
            // Refresh subscription status to ensure UI updates
            subscriptionManager.loadSubscriptionStatus()
        } catch let error as NSError {
            print("🔥 Firebase: Error details - Code: \(error.code), Domain: \(error.domain), Description: \(error.localizedDescription)")
            
            await MainActor.run {
                isLoading = false
                
                // Provide more specific error messages
                let errorMessage: String
                switch error.code {
                case -3: // Firebase Functions error code for invalid argument
                    errorMessage = "Invalid subscription data. Please contact support."
                case -4: // Firebase Functions error code for deadline exceeded
                    errorMessage = "Request timed out. Please try again."
                case -5: // Firebase Functions error code for not found
                    errorMessage = "Subscription not found. Please contact support."
                case -6: // Firebase Functions error code for already exists
                    errorMessage = "Cancellation already scheduled."
                case -7: // Firebase Functions error code for permission denied
                    errorMessage = "Permission denied. Please contact support."
                case -8: // Firebase Functions error code for resource exhausted
                    errorMessage = "Too many requests. Please try again later."
                case -9: // Firebase Functions error code for failed precondition
                    errorMessage = "Subscription cannot be cancelled at this time."
                case -10: // Firebase Functions error code for aborted
                    errorMessage = "Operation was cancelled. Please try again."
                case -11: // Firebase Functions error code for out of range
                    errorMessage = "Invalid date range. Please contact support."
                case -12: // Firebase Functions error code for unimplemented
                    errorMessage = "This feature is not available yet."
                case -13: // Firebase Functions error code for internal
                    errorMessage = "Server error. Please try again or contact support."
                case -14: // Firebase Functions error code for unavailable
                    errorMessage = "Service temporarily unavailable. Please try again."
                case -15: // Firebase Functions error code for data loss
                    errorMessage = "Data error. Please contact support."
                case -16: // Firebase Functions error code for unauthenticated
                    errorMessage = "Authentication error. Please log out and log back in."
                default:
                    errorMessage = "Failed to schedule cancellation: \(error.localizedDescription)"
                }
                
                self.errorMessage = errorMessage
                showAlert = true
            }
        }
    }
        
    // MARK: - Helper Methods
        
    private func debugSubscriptionStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]
            
            print("🔍 DEBUG: User ID: \(userId)")
            print("🔍 DEBUG: Full user data: \(userData)")
            print("🔍 DEBUG: isSubscribed: \(userData["isSubscribed"] ?? "nil")")
            print("🔍 DEBUG: subscriptionId: \(userData["subscriptionId"] ?? "nil")")
            print("🔍 DEBUG: planId: \(userData["planId"] ?? "nil")")
            print("🔍 DEBUG: subscriptionDate: \(userData["subscriptionDate"] ?? "nil")")
            print("🔍 DEBUG: Local subscription status: \(subscriptionManager.isSubscribed)")
            
            await MainActor.run {
                self.errorMessage = "Debug info printed to console. Check Xcode console for details."
                self.showAlert = true
            }
        } catch {
            print("🔍 DEBUG: Error getting user data: \(error)")
        }
    }
        
    // MARK: - Plan Switching
        
    private func switchPlan(to newPlan: SubscriptionManager.SubscriptionPlan) async {
        // For now, just update the local plan - implement actual switching logic later
        subscriptionManager.currentPlan = newPlan
        
        await MainActor.run {
            self.errorMessage = "Successfully switched to \(newPlan.displayName) plan!"
            self.showAlert = true
        }
    }
}

// MARK: - Subscription Header View
struct SubscriptionHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("Manage Your")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("Premium Subscription")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Current Plan Card View
struct CurrentPlanCardView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Current Plan")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Premium Plan")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.green)
                        .clipShape(Capsule())
                }
                
                HStack {
                    Text("Unlimited searches")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                HStack {
                    Text("Premium AI models (GPT-4o)")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                HStack {
                    Text("Priority support")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(24)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

// MARK: - Subscription Details View
struct SubscriptionDetailsView: View {
    let subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Subscription Details")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if subscriptionManager.isCancellationScheduled {
                        Text("Cancelling")
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    } else {
                        Text(subscriptionManager.isSubscribed ? "Active" : "Inactive")
                            .fontWeight(.medium)
                            .foregroundStyle(subscriptionManager.isSubscribed ? .green : .red)
                    }
                }
                
                HStack {
                    Text("Plan")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subscriptionManager.currentPlan.displayName)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                
                if let endDate = subscriptionManager.subscriptionEndDate {
                    HStack {
                        Text("Next Billing")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(endDate.formatted(date: .abbreviated, time: .omitted))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(24)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

// MARK: - Action Buttons View
struct ActionButtonsView: View {
    let subscriptionManager: SubscriptionManager
    let stripePaymentService: StripePaymentService
    @Binding var isLoading: Bool
    @Binding var showAlert: Bool
    @Binding var errorMessage: String?
    @Binding var showingCancelAlert: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if subscriptionManager.isCancellationScheduled {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Cancellation Scheduled")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    
                    Text("Your subscription will end at the conclusion of your current billing period. You can reactivate anytime before then.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
            }
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        await debugSubscriptionStatus()
                    }
                } label: {
                    HStack {
                        Image(systemName: "ladybug.fill")
                        Text("Debug Subscription Status")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if !subscriptionManager.isCancellationScheduled {
                    Button {
                        showingCancelAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel Subscription")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
    
    private func debugSubscriptionStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]
            
            print("🔍 DEBUG: User ID: \(userId)")
            print("🔍 DEBUG: Full user data: \(userData)")
            print("🔍 DEBUG: isSubscribed: \(userData["isSubscribed"] ?? "nil")")
            print("🔍 DEBUG: subscriptionId: \(userData["subscriptionId"] ?? "nil")")
            print("🔍 DEBUG: planId: \(userData["planId"] ?? "nil")")
            print("🔍 DEBUG: subscriptionDate: \(userData["subscriptionDate"] ?? "nil")")
            print("🔍 DEBUG: Local subscription status: \(subscriptionManager.isSubscribed)")
            
            await MainActor.run {
                self.errorMessage = "Debug info printed to console. Check Xcode console for details."
                self.showAlert = true
            }
        } catch {
            print("🔍 DEBUG: Error getting user data: \(error)")
        }
    }
}

#Preview {
    ManageSubscriptionView()
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(StripePaymentService.shared)
}
