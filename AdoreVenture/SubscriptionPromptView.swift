//
//  SubscriptionPromptView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/24/25.
//

import SwiftUI

struct SubscriptionPromptView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var stripePaymentService: StripePaymentService
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaymentView = false
    
    var body: some View {
        ZStack {
            AVTheme.gradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                        
                        Text("Unlock Unlimited Adventures!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("You've used all your free searches for today. Upgrade to Premium for unlimited access!")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
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
                                freeValue: "2 per day",
                                premiumValue: "Unlimited",
                                icon: "magnifyingglass"
                            )
                            
                            ComparisonRow(
                                feature: "AI Suggestions",
                                freeValue: "Basic",
                                premiumValue: "Premium",
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
                    
                    // Pricing
                    VStack(spacing: 16) {
                        Text("Choose Your Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 12) {
                            PricingCard(
                                title: "Monthly",
                                price: "$4.99",
                                period: "per month",
                                isPopular: false
                            )
                            
                            PricingCard(
                                title: "Annual",
                                price: "$39.99",
                                period: "per year",
                                savings: "Save 33%",
                                isPopular: true
                            )
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button {
                            showingPaymentView = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Choose Plan")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.yellow)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // Test button for immediate upgrade (remove in production)
                        Button {
                            Task {
                                let success = await subscriptionManager.purchaseSubscription()
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Upgrade Now (Test)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
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
        .navigationTitle("Upgrade to Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingPaymentView) {
            PaymentView()
                .environmentObject(subscriptionManager)
                .environmentObject(stripePaymentService)
        }
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Image(systemName: "creditcard.fill")
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
                    
                    // Placeholder for actual purchase implementation
                    VStack(spacing: 16) {
                        Button {
                            // TODO: Implement actual purchase
                            Task {
                                let success = await subscriptionManager.purchaseSubscription()
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text("Subscribe with Apple Pay")
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
