//
//  SubscriptionPromptView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/24/25.
//

import SwiftUI
import StripePaymentSheet
import PassKit

struct SubscriptionPromptView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var stripePaymentService: StripePaymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showingPaymentSheet = false
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentSuccess = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AVTheme.gradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fixed header that never scrolls
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    Text("Unlock Unlimited Adventures!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("You've used all your free searches for this month. Upgrade to Premium for unlimited access!")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 25) // Further reduced safe area padding
                .padding(.bottom, 20)
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 30) {
                    
                    // Features
                    VStack(spacing: 20) {
                        Text("Premium Features")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "infinity",
                                title: "Unlimited Searches",
                                description: "Search as many times as you want, every month"
                            )
                            
                            FeatureRow(
                                icon: "sparkles",
                                title: "Premium AI Models",
                                description: "Access to GPT-4o and advanced AI models for better suggestions"
                            )
                            
                            FeatureRow(
                                icon: "bookmark.fill",
                                title: "Unlimited Bookmarks",
                                description: "Save as many activities as you want"
                            )
                            
                            FeatureRow(
                                icon: "arrow.up.circle.fill",
                                title: "Priority Support",
                                description: "Get help faster when you need it"
                            )
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Comparison Section
                    VStack(spacing: 16) {
                        Text("Free vs Premium")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 12) {
                            ComparisonRow(
                                feature: "Bookmarks",
                                freeValue: "Limited",
                                premiumValue: "Unlimited",
                                icon: "bookmark.fill"
                            )
                            
                            ComparisonRow(
                                feature: "Searches",
                                freeValue: "16 per month",
                                premiumValue: "Unlimited",
                                icon: "magnifyingglass"
                            )
                            
                            ComparisonRow(
                                feature: "AI Models",
                                freeValue: "GPT-4o Mini",
                                premiumValue: "GPT-4o + Advanced",
                                icon: "sparkles"
                            )
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Plan Selection
                    VStack(spacing: 16) {
                        Text("Choose Your Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 12) {
                            InteractivePlanCard(
                                plan: stripePaymentService.monthlyPlan,
                                isSelected: selectedPlan?.id == stripePaymentService.monthlyPlan.id,
                                isPopular: false
                            ) {
                                selectedPlan = stripePaymentService.monthlyPlan
                            }
                            
                            InteractivePlanCard(
                                plan: stripePaymentService.yearlyPlan,
                                isSelected: selectedPlan?.id == stripePaymentService.yearlyPlan.id,
                                isPopular: true
                            ) {
                                selectedPlan = stripePaymentService.yearlyPlan
                            }
                        }
                    }
                    
                    // Payment Methods Section (always shown)
                    VStack(spacing: 20) {
                        Text("Payment Method")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 16) {
                            // Payment Methods Button
                            Button {
                                guard let plan = selectedPlan, !isLoading else { return }
                                isLoading = true
                                Task {
                                    await processPayment(for: plan)
                                }
                            } label: {
                                                            HStack {
                                Image(systemName: "creditcard.and.123")
                                    .font(.title2)
                                Text("Payment Methods")
                                    .fontWeight(.semibold)
                            }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedPlan != nil ? .yellow : .secondary)
                                .foregroundStyle(selectedPlan != nil ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(isLoading || selectedPlan == nil)
                            

                            
                            if selectedPlan == nil {
                                Text("Select a plan above to enable payment")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundStyle(.white)
                                    Text("Processing payment...")
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Other Action Buttons
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await subscriptionManager.restorePurchases()
                            }
                        } label: {
                            Text("Restore Purchases")
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Maybe Later")
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(24)
            }
        }
    }
        .navigationTitle("Upgrade to Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: showingPaymentSheet) { show in
            if show, let paymentSheet = paymentSheet {
                print("🔄 Attempting to present PaymentSheet...")
                
                // Add a small delay to ensure any existing presentations are complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Find the view controller that's presenting this view
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        
                        // Try to find the presenting view controller
                        var presentingViewController = rootViewController
                        
                        // Walk up the presentation hierarchy to find the topmost presented view controller
                        while let presented = presentingViewController.presentedViewController {
                            presentingViewController = presented
                        }
                        
                        print("📱 Found presenting view controller: \(type(of: presentingViewController))")
                        print("📱 Is already presenting: \(presentingViewController.presentedViewController != nil)")
                        
                        // Check if the view controller is already presenting
                        if presentingViewController.presentedViewController == nil {
                            print("✅ Presenting PaymentSheet...")
                            paymentSheet.present(from: presentingViewController) { result in
                                print("💳 PaymentSheet result: \(result)")
                                handlePaymentResult(result)
                                showingPaymentSheet = false
                            }
                        } else {
                            // If already presenting, reset the state
                            print("⚠️ Already presenting, resetting state")
                            showingPaymentSheet = false
                            isLoading = false
                        }
                    } else {
                        print("❌ Could not find root view controller")
                        showingPaymentSheet = false
                        isLoading = false
                    }
                }
            }
        }
        .alert("Payment Error", isPresented: $showingError) {
            Button("OK") { 
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "There was an error processing your payment. Please try again.")
        }
        .alert("Payment Successful!", isPresented: $paymentSuccess) {
            Button("Great!") {
                dismiss()
            }
        } message: {
            Text("Welcome to Premium! You now have unlimited access to all features.")
        }
    }
    
    // MARK: - Payment Processing (PaymentSheet)
    
    private func processPayment(for plan: SubscriptionPlan) async {
        print("💳 Starting payment process for plan: \(plan.name)")
        
        do {
            // Create payment intent
            print("💳 Creating payment intent...")
            guard let paymentIntent = try await stripePaymentService.createPaymentIntent(for: plan) else {
                throw NSError(domain: "PaymentError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create payment intent"])
            }
            
            print("💳 Payment intent created successfully")
            
            // Configure payment sheet
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "AdoreVenture"
            configuration.defaultBillingDetails = .init()
            
            // Set return URL for payment methods that require it
            configuration.returnURL = "adoreventure://payment-return"
            
            // Enable Apple Pay in PaymentSheet
            configuration.applePay = .init(
                merchantId: "merchant.com.dagmawimulualem.adoreventure",
                merchantCountryCode: "US"
            )
            
            // Configure payment method types explicitly
            configuration.allowsDelayedPaymentMethods = false
            
            // Note: Customer configuration is not available in the current PaymentIntent structure
            // PaymentSheet will work without customer configuration for basic payments
            
            let sheet = PaymentSheet(paymentIntentClientSecret: paymentIntent.clientSecret, configuration: configuration)
            
            print("💳 PaymentSheet configured, setting state...")
            
            await MainActor.run {
                self.paymentSheet = sheet
                self.showingPaymentSheet = true
                self.isLoading = false
                print("💳 State updated - paymentSheet: \(self.paymentSheet != nil), showingPaymentSheet: \(self.showingPaymentSheet)")
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.showingError = true
            }
            print("❌ Payment error: \(error)")
        }
    }
    

    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            Task {
                await subscriptionManager.updateSubscriptionStatus(true)
                await MainActor.run {
                    self.paymentSuccess = true
                }
            }
        case .failed(let error):
            print("Payment failed: \(error)")
            showingError = true
        case .canceled:
            print("Payment canceled")
        }
    }
}

// MARK: - Supporting Views

struct InteractivePlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isPopular: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(plan.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        if isPopular {
                            Text("BEST VALUE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.yellow)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(String(format: "%.2f", plan.price))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("/\(plan.displayInterval)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    if plan.interval == "year" {
                        Text("Save 33%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.yellow)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .yellow : .white.opacity(0.6))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? .green.opacity(0.2) : .white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? .green : .white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isPopular: Bool
    
    init(title: String, price: String, period: String, savings: String? = nil, isPopular: Bool = false) {
        self.title = title
        self.price = price
        self.period = period
        self.savings = savings
        self.isPopular = isPopular
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if isPopular {
                Text("MOST POPULAR")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(price)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(period)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            if let savings = savings {
                Text(savings)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )

    }
}

struct ComparisonRow: View {
    let feature: String
    let freeValue: String
    let premiumValue: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 24)
            
            Text(feature)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 4) {
                Text(freeValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .strikethrough()
                
                Text(premiumValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 8)
    }
}

struct PurchaseView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var stripePaymentService = StripePaymentService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    Text("Complete Your Purchase")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Choose your preferred payment method and complete your subscription to unlock unlimited adventures!")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // Payment Options
                    VStack(spacing: 16) {
                        // Regular Payment Button
                        Button {
                            // Navigate to full payment view
                            dismiss()
                            // You might want to present the PaymentView here
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.and.123")
                                Text("Other Payment Methods")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.yellow)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

        }
    }
    

}

#Preview {
    SubscriptionPromptView()
        .environmentObject(SubscriptionManager.shared)
}
