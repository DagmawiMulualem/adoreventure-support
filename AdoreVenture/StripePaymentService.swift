//
//  StripePaymentService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import FirebaseFunctions

// MARK: - Payment Models

struct PaymentIntent: Codable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let clientSecret: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case currency
        case status
        case clientSecret = "client_secret"
    }
}

struct SubscriptionPlan: Identifiable, Codable {
    let id: String
    let name: String
    let price: Double
    let currency: String
    let interval: String // "month" or "year"
    let features: [String]
    let stripePriceId: String
    
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    
    var displayInterval: String {
        return interval == "month" ? "month" : "year"
    }
}

struct PaymentResult {
    let success: Bool
    let message: String
    let subscriptionId: String?
    let error: Error?
}

// MARK: - Stripe Payment Service

class StripePaymentService: ObservableObject {
    static let shared = StripePaymentService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let functions = Functions.functions()
    
    // Subscription plans
    let monthlyPlan = SubscriptionPlan(
        id: "monthly_premium",
        name: "Monthly Premium",
        price: 4.99,
        currency: "usd",
        interval: "month",
        features: [
            "Unlimited searches every day",
            "Premium AI suggestions",
            "Unlimited bookmarks",
            "Priority support",
            "Ad-free experience"
        ],
        stripePriceId: "price_monthly_premium" // Replace with your actual Stripe price ID
    )
    
    let yearlyPlan = SubscriptionPlan(
        id: "yearly_premium",
        name: "Yearly Premium",
        price: 39.99,
        currency: "usd",
        interval: "year",
        features: [
            "Everything in Monthly Premium",
            "Save 33% compared to monthly",
            "Early access to new features",
            "Exclusive premium content"
        ],
        stripePriceId: "price_yearly_premium" // Replace with your actual Stripe price ID
    )
    
    private init() {
        print("💳 Stripe: Payment service initialized")
    }
    
    // MARK: - Payment Methods
    
    func createPaymentIntent(for plan: SubscriptionPlan) async -> PaymentIntent? {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data: [String: Any] = [
                "planId": plan.id,
                "stripePriceId": plan.stripePriceId,
                "amount": Int(plan.price * 100), // Convert to cents
                "currency": plan.currency
            ]
            
            let result = try await functions.httpsCallable("createPaymentIntent").call(data)
            
            guard let response = result.data as? [String: Any],
                  let paymentIntentData = response["paymentIntent"] as? [String: Any] else {
                throw NSError(domain: "StripePaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: paymentIntentData)
            let paymentIntent = try JSONDecoder().decode(PaymentIntent.self, from: jsonData)
            
            await MainActor.run {
                isLoading = false
            }
            
            print("💳 Stripe: Payment intent created - \(paymentIntent.id)")
            return paymentIntent
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to create payment: \(error.localizedDescription)"
            }
            print("💳 Stripe: Error creating payment intent - \(error.localizedDescription)")
            return nil
        }
    }
    
    func confirmPayment(paymentIntentId: String, paymentMethodId: String) async -> PaymentResult {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data: [String: Any] = [
                "paymentIntentId": paymentIntentId,
                "paymentMethodId": paymentMethodId
            ]
            
            let result = try await functions.httpsCallable("confirmPayment").call(data)
            
            guard let response = result.data as? [String: Any] else {
                throw NSError(domain: "StripePaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let success = response["success"] as? Bool ?? false
            let message = response["message"] as? String ?? "Payment completed"
            let subscriptionId = response["subscriptionId"] as? String
            
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = message
                }
            }
            
            print("💳 Stripe: Payment confirmed - Success: \(success)")
            return PaymentResult(success: success, message: message, subscriptionId: subscriptionId, error: nil)
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Payment failed: \(error.localizedDescription)"
            }
            print("💳 Stripe: Error confirming payment - \(error.localizedDescription)")
            return PaymentResult(success: false, message: error.localizedDescription, subscriptionId: nil, error: error)
        }
    }
    
    func createSubscription(for plan: SubscriptionPlan, paymentMethodId: String) async -> PaymentResult {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data: [String: Any] = [
                "planId": plan.id,
                "stripePriceId": plan.stripePriceId,
                "paymentMethodId": paymentMethodId,
                "interval": plan.interval
            ]
            
            let result = try await functions.httpsCallable("createSubscription").call(data)
            
            guard let response = result.data as? [String: Any] else {
                throw NSError(domain: "StripePaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let success = response["success"] as? Bool ?? false
            let message = response["message"] as? String ?? "Subscription created"
            let subscriptionId = response["subscriptionId"] as? String
            
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = message
                }
            }
            
            print("💳 Stripe: Subscription created - Success: \(success), ID: \(subscriptionId ?? "none")")
            return PaymentResult(success: success, message: message, subscriptionId: subscriptionId, error: nil)
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Subscription failed: \(error.localizedDescription)"
            }
            print("💳 Stripe: Error creating subscription - \(error.localizedDescription)")
            return PaymentResult(success: false, message: error.localizedDescription, subscriptionId: nil, error: error)
        }
    }
    
    func cancelSubscription(subscriptionId: String) async -> PaymentResult {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data: [String: Any] = [
                "subscriptionId": subscriptionId
            ]
            
            let result = try await functions.httpsCallable("cancelSubscription").call(data)
            
            guard let response = result.data as? [String: Any] else {
                throw NSError(domain: "StripePaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let success = response["success"] as? Bool ?? false
            let message = response["message"] as? String ?? "Subscription cancelled"
            
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = message
                }
            }
            
            print("💳 Stripe: Subscription cancelled - Success: \(success)")
            return PaymentResult(success: success, message: message, subscriptionId: subscriptionId, error: nil)
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Cancellation failed: \(error.localizedDescription)"
            }
            print("💳 Stripe: Error cancelling subscription - \(error.localizedDescription)")
            return PaymentResult(success: false, message: error.localizedDescription, subscriptionId: nil, error: error)
        }
    }
    
    func getSubscriptionStatus() async -> [String: Any]? {
        do {
            let result = try await functions.httpsCallable("getSubscriptionStatus").call()
            
            guard let response = result.data as? [String: Any] else {
                return nil
            }
            
            print("💳 Stripe: Subscription status retrieved")
            return response
            
        } catch {
            print("💳 Stripe: Error getting subscription status - \(error.localizedDescription)")
            return nil
        }
    }
}
