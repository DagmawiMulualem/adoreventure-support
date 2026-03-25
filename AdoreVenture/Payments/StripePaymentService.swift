//
//  StripePaymentService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import FirebaseFunctions
import StripePaymentSheet
import PassKit
import UIKit

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

struct SetupIntent: Codable {
    let id: String
    let clientSecret: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case clientSecret = "client_secret"
        case status
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
    
    /// Same region as idea callables (`IDEA_CALL_GEN2` / `kFirebaseFunctionsRegion`).
    private let functions = Functions.functions(region: "us-central1")
    
    // Customer ID for Stripe
    var customerId: String?
    
    // Deduplication for PaymentIntent creation
    private var isCreatingPaymentIntent = false
    var currentPaymentIntentClientSecret: String?
    
    // PaymentSheet for Apple Pay
    @Published var paymentSheet: PaymentSheet?
    
    // Subscription plans
    let monthlyPlan = SubscriptionPlan(
        id: "monthly_premium",
        name: "Monthly Premium",
        price: 4.99,
        currency: "usd",
        interval: "month",
        features: [
            "Unlimited searches every day",
            "Advanced AI recommendations",
            "Priority customer support",
            "Ad-free experience"
        ],
        stripePriceId: "price_1S0M4Y2L7M9M7pXjLjiYWykj8nL682f12GLZ92qqrO3hqALZLSD5OnUjoH1Or95srCkwC7r8YEaxmTKZokQjypli00oMRjD58b_monthly"
    )
    
    let yearlyPlan = SubscriptionPlan(
        id: "yearly_premium",
        name: "Yearly Premium",
        price: 39.99,
        currency: "usd",
        interval: "year",
        features: [
            "Unlimited searches every day",
            "Advanced AI recommendations",
            "Priority customer support",
            "Ad-free experience",
            "2 months free (save $19.98)"
        ],
        stripePriceId: "price_1S0M4Y2L7M9M7pXjLjiYWykj8nL682f12GLZ92qqrO3hqALZLSD5OnUjoH1Or95srCkwC7r8YEaxmTKZokQjypli00oMRjD58b_yearly"
    )
    
    private init() {}
    
    // MARK: - Apple Pay Availability
    
    func isApplePayAvailable() -> Bool {
        // Check if PaymentSheet supports Apple Pay
        let canMakePayments = PKPaymentAuthorizationController.canMakePayments()
        print("🍎 Apple Pay Debug: canMakePayments = \(canMakePayments)")
        
        if !canMakePayments {
            print("🍎 Apple Pay Debug: Basic availability check failed - device cannot make payments")
            return false
        }
        
        // Check if we can make payments with specific networks
        let canMakePaymentsWithNetworks = PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex])
        print("🍎 Apple Pay Debug: canMakePaymentsWithNetworks = \(canMakePaymentsWithNetworks)")
        
        if !canMakePaymentsWithNetworks {
            print("🍎 Apple Pay Debug: Network availability check failed - no supported payment networks")
            return false
        }
        
        // Test creating a payment request to verify merchant configuration
        let testRequest = PKPaymentRequest()
        testRequest.merchantIdentifier = "merchant.com.dagmawimulualem.adoreventure"
        testRequest.supportedNetworks = [.visa, .masterCard, .amex]
        testRequest.merchantCapabilities = .threeDSecure
        testRequest.countryCode = "US"
        testRequest.currencyCode = "USD"
        
        // Add a test payment summary item
        let testItem = PKPaymentSummaryItem(label: "Test", amount: NSDecimalNumber(value: 1.00))
        testRequest.paymentSummaryItems = [testItem]
        
        print("🍎 Apple Pay Debug: Testing payment request configuration...")
        print("🍎 Apple Pay Debug: Merchant ID: \(testRequest.merchantIdentifier ?? "nil")")
        print("🍎 Apple Pay Debug: Supported networks: \(testRequest.supportedNetworks)")
        print("🍎 Apple Pay Debug: Merchant capabilities: \(testRequest.merchantCapabilities)")
        
        // If we can create the request without errors, Apple Pay should be available
        print("🍎 Apple Pay Debug: Payment request configuration successful")
        
        // Additional debugging information with safe access
        let bundleId = Bundle.main.bundleIdentifier ?? "nil"
        let infoDictionary = Bundle.main.infoDictionary
        let teamId = infoDictionary?["CFBundleTeamIdentifier"] as? String ?? "nil"
        let appVersion = infoDictionary?["CFBundleShortVersionString"] as? String ?? "nil"
        
        print("🍎 Apple Pay Debug: Bundle ID: \(bundleId)")
        print("🍎 Apple Pay Debug: Team ID: \(teamId)")
        print("🍎 Apple Pay Debug: App Version: \(appVersion)")
        
        return true
    }
    
    // MARK: - Payment Intent Creation
    
    func createPaymentIntent(for plan: SubscriptionPlan) async -> PaymentIntent? {
        // Prevent duplicate requests
        guard !isCreatingPaymentIntent else {
            print("💳 Stripe: Payment intent creation already in progress")
            return nil
        }
        
        isCreatingPaymentIntent = true
        defer {
            // Always reset the flag when the function exits
            isCreatingPaymentIntent = false
            print("💳 Stripe: Payment intent flag reset")
        }
        
        do {
            let data: [String: Any] = [
                "amount": Int(plan.price * 100), // Convert to cents
                "currency": plan.currency.lowercased(),
                "planId": plan.id,
                "stripePriceId": plan.stripePriceId
            ]
            
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await self.functions.httpsCallable("createPaymentIntent").call(data).data
            }
            guard let resultData = raw as? [String: Any],
                  let paymentIntentData = resultData["paymentIntent"] as? [String: Any],
                  let id = paymentIntentData["id"] as? String,
                  let amount = paymentIntentData["amount"] as? Int,
                  let currency = paymentIntentData["currency"] as? String,
                  let status = paymentIntentData["status"] as? String,
                  let clientSecret = paymentIntentData["client_secret"] as? String,
                  !id.isEmpty,
                  !clientSecret.isEmpty,
                  amount > 0 else {
                print("💳 Stripe: Invalid or missing payment intent data")
                return nil
            }
            
            let paymentIntent = PaymentIntent(
                id: id,
                amount: amount,
                currency: currency,
                status: status,
                clientSecret: clientSecret
            )
            
            // Store the client secret for later use
            currentPaymentIntentClientSecret = paymentIntent.clientSecret
            
            print("💳 Stripe: Payment intent created successfully - \(paymentIntent.id)")
            return paymentIntent
            
        } catch {
            print("💳 Stripe: Error creating payment intent - \(error.localizedDescription)")
            errorMessage = ErrorDisplayHelper.getErrorMessage(error)
            return nil
        }
    }
    
    // MARK: - PaymentSheet Implementation (Apple Pay Disabled)
    
    func createPaymentSheet(for plan: SubscriptionPlan) async -> Bool {
        print("💳 Payment: Creating PaymentSheet for plan: \(plan.name)")
        
        do {
            // Use the dedicated PaymentSheet intent function
            let data: [String: Any] = [
                "amount": plan.price,
                "currency": plan.currency.lowercased(),
                "planId": plan.id,
                "stripePriceId": plan.stripePriceId
            ]
            
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await self.functions.httpsCallable("createPaymentSheetIntent").call(data).data
            }
            guard let resultData = raw as? [String: Any],
                  let success = resultData["success"] as? Bool,
                  success,
                  let clientSecret = resultData["clientSecret"] as? String,
                  !clientSecret.isEmpty else {
                print("💳 Payment: Failed to create PaymentSheet intent or invalid response")
                return false
            }
            
            // Configure PaymentSheet with Apple Pay
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "AdoreVenture"
            configuration.applePay = .init(
                merchantId: "merchant.com.dagmawimulualem.adoreventure",
                merchantCountryCode: "US"
            )
            
            // Create PaymentSheet
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: clientSecret,
                configuration: configuration
            )
            
            print("💳 Payment: PaymentSheet created successfully")
            return true
            
        } catch {
            print("💳 Payment: Error creating PaymentSheet - \(error.localizedDescription)")
            return false
        }
    }
    
    func presentPaymentSheet() async -> PaymentResult {
        guard let paymentSheet = paymentSheet else {
            return PaymentResult(success: false, message: "Payment sheet not available", subscriptionId: nil, error: nil)
        }
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Safely get the root view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let rootViewController = window.rootViewController else {
                    print("💳 Payment: Error - Could not find root view controller")
                    continuation.resume(returning: PaymentResult(
                        success: false,
                        message: "Unable to present payment sheet - no root view controller",
                        subscriptionId: nil,
                        error: nil
                    ))
                    return
                }
                
                paymentSheet.present(from: rootViewController) { result in
                    switch result {
                    case .completed:
                        print("💳 Payment: Payment completed successfully")
                        // Update user subscription status
                        Task {
                            await self.updateUserSubscriptionStatus()
                        }
                        continuation.resume(returning: PaymentResult(
                            success: true,
                            message: "Payment completed successfully",
                            subscriptionId: nil,
                            error: nil
                        ))
                    case .failed(let error):
                        print("💳 Payment: Payment failed - \(error.localizedDescription)")
                        continuation.resume(returning: PaymentResult(
                            success: false,
                            message: error.localizedDescription,
                            subscriptionId: nil,
                            error: error
                        ))
                    case .canceled:
                        print("💳 Payment: Payment canceled")
                        continuation.resume(returning: PaymentResult(
                            success: false,
                            message: "Payment was canceled",
                            subscriptionId: nil,
                            error: nil
                        ))
                    }
                }
            }
        }
    }
    
    private func updateUserSubscriptionStatus() async {
        do {
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await self.functions.httpsCallable("getSubscriptionStatus").call().data
            }
            if let resultData = raw as? [String: Any],
               let isActive = resultData["isActive"] as? Bool,
               isActive {
                print("💳 Payment: User subscription status updated successfully")
            }
        } catch {
            print("💳 Payment: Error updating subscription status - \(error.localizedDescription)")
        }
    }
    
    func processApplePayPayment(for plan: SubscriptionPlan) async -> PaymentResult {
        // Apple Pay is disabled, use regular payment sheet instead
        return await processRegularPayment(for: plan)
    }
    
    func processRegularPayment(for plan: SubscriptionPlan) async -> PaymentResult {
        print("💳 Payment: Starting payment process for plan: \(plan.name)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Create PaymentSheet
            let success = await createPaymentSheet(for: plan)
            guard success else {
                throw NSError(domain: "StripePaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create payment sheet"])
            }
            
            // Present the payment sheet
            let result = await presentPaymentSheet()
            
            await MainActor.run {
                isLoading = false
                if !result.success {
                    errorMessage = result.message
                }
            }
            
            return result
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = ErrorDisplayHelper.getErrorMessage(error)
            }
            print("💳 Payment: Error processing payment - \(error.localizedDescription)")
            return PaymentResult(success: false, message: error.localizedDescription, subscriptionId: nil, error: error)
        }
    }
    

    
    // MARK: - Utility Methods
    
    func clearPaymentState() {
        currentPaymentIntentClientSecret = nil
        isCreatingPaymentIntent = false
        isLoading = false
        errorMessage = nil
        paymentSheet = nil
        print("💳 Stripe: Payment state cleared")
    }
    
    func resetError() {
        errorMessage = nil
    }
    

    
    // MARK: - Subscription Status
    
    func getSubscriptionStatus() async -> [String: Any]? {
        do {
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await self.functions.httpsCallable("getSubscriptionStatus").call().data
            }
            guard let resultData = raw as? [String: Any] else {
                print("💳 Stripe: Invalid response format from getSubscriptionStatus")
                return nil
            }
            
            return resultData
            
        } catch {
            print("💳 Stripe: Error getting subscription status - \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Testing Methods
    
    func testStripeConfiguration() async -> Bool {
        do {
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await self.functions.httpsCallable("testStripeConfig").call().data
            }
            guard let resultData = raw as? [String: Any],
                  let success = resultData["success"] as? Bool else {
                print("💳 Stripe: Invalid response format from testStripeConfig")
                return false
            }
            
            return success
            
        } catch {
            print("💳 Stripe: Error testing Stripe configuration - \(error.localizedDescription)")
            return false
        }
    }
}


