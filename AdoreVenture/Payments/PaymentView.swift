//
//  PaymentView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import StripePaymentSheet
import PassKit

struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var stripePaymentService = StripePaymentService.shared
    
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showingPaymentSheet = false
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentSuccess = false
    @State private var showingError = false
    /// Set synchronously on tap to prevent double-tap / "already running" requests
    @State private var isPaymentInProgress = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.yellow)
                            
                            Text("Upgrade to Premium")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("Unlock unlimited adventures and premium features")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Plan Selection
                        VStack(spacing: 20) {
                            Text("Choose Your Plan")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 16) {
                                PlanCard(
                                    plan: stripePaymentService.monthlyPlan,
                                    isSelected: selectedPlan?.id == stripePaymentService.monthlyPlan.id,
                                    isPopular: false
                                ) {
                                    selectedPlan = stripePaymentService.monthlyPlan
                                }
                                
                                PlanCard(
                                    plan: stripePaymentService.yearlyPlan,
                                    isSelected: selectedPlan?.id == stripePaymentService.yearlyPlan.id,
                                    isPopular: true
                                ) {
                                    selectedPlan = stripePaymentService.yearlyPlan
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Features
                        if selectedPlan != nil {
                            VStack(spacing: 16) {
                                Text("What's Included")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                
                                VStack(spacing: 12) {
                                    PaymentFeatureRow(
                                        icon: "infinity",
                                        text: "Unlimited Searches"
                                    )
                                    
                                    PaymentFeatureRow(
                                        icon: "sparkles",
                                        text: "Premium AI Suggestions"
                                    )
                                    
                                    PaymentFeatureRow(
                                        icon: "bookmark.fill",
                                        text: "Unlimited Bookmarks"
                                    )
                                    
                                    PaymentFeatureRow(
                                        icon: "arrow.up.circle.fill",
                                        text: "Priority Support"
                                    )
                                    
                                    PaymentFeatureRow(
                                        icon: "xmark.circle.fill",
                                        text: "Ad-Free Experience"
                                    )
                                }
                                .padding(24)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            // Payment Options
                            VStack(spacing: 16) {
                                // Apple Pay Button (if available)
                                if stripePaymentService.isApplePayAvailable() {
                                    Button {
                                        guard !isPaymentInProgress, !stripePaymentService.isLoading, selectedPlan != nil else { return }
                                        isPaymentInProgress = true
                                        Task {
                                            await processApplePayPayment()
                                            await MainActor.run { isPaymentInProgress = false }
                                        }
                                    } label: {
                                        HStack {
                                            if stripePaymentService.isLoading {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .foregroundStyle(.white)
                                            } else {
                                                Image(systemName: "applelogo")
                                                    .font(.title3)
                                            }
                                            
                                            Text("Pay with Apple Pay")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                        .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                                    }
                                    .disabled(isPaymentInProgress || stripePaymentService.isLoading || selectedPlan == nil)
                                    .padding(.horizontal, 20)
                                }
                                
                                // Regular Payment Button
                                Button {
                                    guard !isPaymentInProgress, !stripePaymentService.isLoading, selectedPlan != nil else { return }
                                    isPaymentInProgress = true
                                    Task {
                                        await preparePaymentSheet()
                                        await MainActor.run { isPaymentInProgress = false }
                                    }
                                } label: {
                                    HStack {
                                        if stripePaymentService.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .foregroundStyle(.white)
                                        } else {
                                            Image(systemName: "creditcard.fill")
                                                .font(.title3)
                                        }
                                        
                                        Text("Subscribe for \(selectedPlan?.displayPrice ?? "")/\(selectedPlan?.displayInterval ?? "")")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(AVTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                                }
                                .disabled(isPaymentInProgress || stripePaymentService.isLoading || selectedPlan == nil)
                                .padding(.horizontal, 20)
                                
                                // Terms and Privacy
                                VStack(spacing: 8) {
                                    Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                    
                                    Text("Cancel anytime. No commitment required.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 20)
                            }
                            .padding(.vertical, 30)
                        }
                    }
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingPaymentSheet, onDismiss: {
            // Clear payment state when sheet is dismissed
            paymentSheet = nil
            stripePaymentService.clearPaymentState()
        }) {
            if let paymentSheet = paymentSheet {
                PaymentSheetView(paymentSheet: paymentSheet) { result in
                    handlePaymentResult(result)
                }
            }
        }
        .alert("Payment Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(stripePaymentService.errorMessage ?? "An error occurred during payment")
        }
        .alert("Payment Successful!", isPresented: $paymentSuccess) {
            Button("Continue") {
                dismiss()
                // Update subscription status
                Task {
                    await subscriptionManager.updateSubscriptionStatus(true)
                }
            }
        } message: {
            Text("Welcome to Premium! You now have unlimited access to all features.")
        }
    }
    
    private func preparePaymentSheet() async {
        guard let selectedPlan = selectedPlan else { return }
        
        // Reset payment sheet state
        await MainActor.run {
            paymentSheet = nil
            showingPaymentSheet = false
        }
        
        // Create a fresh payment intent for the selected plan
        let paymentIntent = await stripePaymentService.createPaymentIntent(for: selectedPlan)
        
        if let paymentIntent = paymentIntent {
            // Use minimal configuration to avoid compatibility issues
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "AdoreVenture"
            configuration.allowsDelayedPaymentMethods = false
            configuration.defaultBillingDetails = .init()
            
            await MainActor.run {
                paymentSheet = PaymentSheet(paymentIntentClientSecret: paymentIntent.clientSecret, configuration: configuration)
                showingPaymentSheet = true
            }
        } else {
            await MainActor.run {
                showingError = true
            }
        }
    }
    
    private func processApplePayPayment() async {
        guard let selectedPlan = selectedPlan else { return }
        
        let result = await stripePaymentService.processApplePayPayment(for: selectedPlan)
        
        if result.success {
            paymentSuccess = true
            // Refresh subscription status
            Task {
                await subscriptionManager.updateSubscriptionStatus(true)
            }
        } else if result.message == "Payment was cancelled" {
            // Handle cancellation gracefully - don't show error
            print("Apple Pay payment was cancelled by user")
        } else {
            showingError = true
        }
    }
    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            paymentSuccess = true
            // Clear payment state
            stripePaymentService.clearPaymentState()
            // Refresh subscription status
            Task {
                await subscriptionManager.updateSubscriptionStatus(true)
            }
        case .canceled:
            print("Payment canceled")
            // Clear payment state on cancel
            stripePaymentService.clearPaymentState()
        case .failed(let error):
            print("Payment failed: \(error.localizedDescription)")
            stripePaymentService.errorMessage = ErrorDisplayHelper.getErrorMessage(error)
            showingError = true
            // Clear payment state on failure
            stripePaymentService.clearPaymentState()
        }
    }
}

// MARK: - PaymentSheet View
struct PaymentSheetView: UIViewControllerRepresentable {
    let paymentSheet: PaymentSheet
    let onCompletion: (PaymentSheetResult) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        
        // Ensure we're on the main thread and the view is visible
        DispatchQueue.main.async {
            if controller.presentedViewController == nil {
                paymentSheet.present(from: controller) { result in
                    onCompletion(result)
                }
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - PaymentSheet Presenter
struct PaymentSheetPresenter: UIViewControllerRepresentable {
    @Binding var paymentSheet: PaymentSheet?
    let onCompletion: (PaymentSheetResult) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        guard let sheet = paymentSheet, vc.presentedViewController == nil else { return }
        
        DispatchQueue.main.async {
            sheet.present(from: vc) { result in
                onCompletion(result)
            }
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Popular Badge
                if isPopular {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Most Popular")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yellow.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Plan Details
                VStack(spacing: 12) {
                    Text(plan.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(plan.displayPrice)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AVTheme.accent)
                        
                        Text("/\(plan.displayInterval)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.features, id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                
                                Text(feature)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AVTheme.accent : .clear, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct PaymentFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AVTheme.accent)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
}
