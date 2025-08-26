//
//  PaymentView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var stripePaymentService: StripePaymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showingPaymentSheet = false
    @State private var paymentSuccess = false
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.yellow)
                            
                            Text("Choose Your Plan")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Unlock unlimited adventures with our premium plans")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Subscription Plans
                        VStack(spacing: 20) {
                            // Monthly Plan
                            PlanCard(
                                plan: stripePaymentService.monthlyPlan,
                                isSelected: selectedPlan?.id == stripePaymentService.monthlyPlan.id,
                                isPopular: false
                            ) {
                                selectedPlan = stripePaymentService.monthlyPlan
                            }
                            
                            // Yearly Plan (Popular)
                            PlanCard(
                                plan: stripePaymentService.yearlyPlan,
                                isSelected: selectedPlan?.id == stripePaymentService.yearlyPlan.id,
                                isPopular: true
                            ) {
                                selectedPlan = stripePaymentService.yearlyPlan
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Payment Button
                        if let selectedPlan = selectedPlan {
                            Button {
                                showingPaymentSheet = true
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
                                    
                                    Text("Subscribe for \(selectedPlan.displayPrice)/\(selectedPlan.displayInterval)")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AVTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                            }
                            .disabled(stripePaymentService.isLoading)
                            .padding(.horizontal, 20)
                        }
                        
                        // Features List
                        VStack(spacing: 16) {
                            Text("What's Included")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 12) {
                                FeatureRow(
                                    icon: "infinity",
                                    title: "Unlimited Searches",
                                    description: "Search as many times as you want, every day"
                                )
                                
                                FeatureRow(
                                    icon: "sparkles",
                                    title: "Premium AI Suggestions",
                                    description: "Get even better, more personalized recommendations"
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
                                
                                FeatureRow(
                                    icon: "xmark.circle.fill",
                                    title: "Ad-Free Experience",
                                    description: "Enjoy a clean, distraction-free interface"
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
        .sheet(isPresented: $showingPaymentSheet) {
            if let selectedPlan = selectedPlan {
                StripePaymentSheet(plan: selectedPlan) { success in
                    showingPaymentSheet = false
                    if success {
                        paymentSuccess = true
                        // Update subscription status
                        Task {
                            await subscriptionManager.updateSubscriptionStatus(true)
                        }
                    }
                }
            }
        }
        .alert("Payment Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(stripePaymentService.errorMessage ?? "An error occurred during payment")
        }
        .onChange(of: stripePaymentService.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("Payment Successful!", isPresented: $paymentSuccess) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Welcome to Premium! You now have unlimited access to all features.")
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

// MARK: - Stripe Payment Sheet

struct StripePaymentSheet: View {
    let plan: SubscriptionPlan
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var stripePaymentService = StripePaymentService.shared
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var cardholderName = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(AVTheme.accent)
                            
                            Text("Complete Payment")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            Text("\(plan.displayPrice)/\(plan.displayInterval)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(AVTheme.accent)
                        }
                        .padding(.top, 20)
                        
                        // Payment Form
                        VStack(spacing: 20) {
                            // Cardholder Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cardholder Name")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                TextField("John Doe", text: $cardholderName)
                                    .textFieldStyle(.roundedBorder)
                                    .textContentType(.name)
                            }
                            
                            // Card Number
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Number")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                TextField("1234 5678 9012 3456", text: $cardNumber)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                    .onChange(of: cardNumber) { _, newValue in
                                        // Format card number with spaces
                                        let cleaned = newValue.replacingOccurrences(of: " ", with: "")
                                        let formatted = cleaned.enumerated().map { index, char in
                                            index > 0 && index % 4 == 0 ? " \(char)" : String(char)
                                        }.joined()
                                        cardNumber = formatted
                                    }
                            }
                            
                            // Expiry and CVV
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Expiry Date")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    TextField("MM/YY", text: $expiryDate)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .onChange(of: expiryDate) { _, newValue in
                                            // Format expiry date
                                            let cleaned = newValue.replacingOccurrences(of: "/", with: "")
                                            if cleaned.count >= 2 {
                                                let formatted = cleaned.prefix(2) + "/" + cleaned.dropFirst(2)
                                                expiryDate = String(formatted.prefix(5))
                                            } else {
                                                expiryDate = cleaned
                                            }
                                        }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("CVV")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    TextField("123", text: $cvv)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .onChange(of: cvv) { _, newValue in
                                            cvv = String(newValue.prefix(4))
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Pay Button
                        Button {
                            Task {
                                await processPayment()
                            }
                        } label: {
                            HStack {
                                if stripePaymentService.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundStyle(.white)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.title3)
                                }
                                
                                Text("Pay \(plan.displayPrice)")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AVTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                        }
                        .disabled(stripePaymentService.isLoading || !isFormValid)
                        .padding(.horizontal, 20)
                        
                        // Security Notice
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(.green)
                                Text("Secure Payment")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.green)
                            }
                            
                            Text("Your payment information is encrypted and secure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Payment Error", isPresented: .constant(stripePaymentService.errorMessage != nil)) {
            Button("OK") {
                stripePaymentService.errorMessage = nil
            }
        } message: {
            Text(stripePaymentService.errorMessage ?? "")
        }
        .alert("Payment Successful!", isPresented: $showingSuccess) {
            Button("Continue") {
                onCompletion(true)
            }
        } message: {
            Text("Your subscription has been activated successfully!")
        }
    }
    
    private var isFormValid: Bool {
        !cardholderName.isEmpty &&
        cardNumber.replacingOccurrences(of: " ", with: "").count >= 13 &&
        expiryDate.count == 5 &&
        cvv.count >= 3
    }
    
    private func processPayment() async {
        // In a real implementation, you would:
        // 1. Create a payment method with Stripe
        // 2. Create a payment intent
        // 3. Confirm the payment
        // 4. Create a subscription
        
        // For now, simulate the payment process
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            showingSuccess = true
        }
    }
}
