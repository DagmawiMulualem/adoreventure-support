//
//  ErrorDisplayView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/26/25.
//

import SwiftUI

extension ErrorDisplayHelper {
    /// Use semantic SwiftUI colors — `Color("name")` looks up the **asset catalog**, not system colors.
    static func swiftUIColor(for error: Error) -> Color {
        switch ErrorHandler.getErrorCategory(error) {
        case .aiService: return .orange
        case .network: return .blue
        case .authentication: return .red
        case .payment: return .purple
        case .username: return .green
        case .firebase: return .orange
        case .generic: return Color.secondary
        }
    }
}

struct ErrorDisplayView: View {
    let error: Error
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    init(error: Error, retryAction: (() -> Void)? = nil, dismissAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: ErrorDisplayHelper.getErrorIcon(error))
                .font(.system(size: 40))
                .foregroundStyle(ErrorDisplayHelper.swiftUIColor(for: error))
            
            // Error Title
            Text(getErrorTitle())
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            
            // Error Message
            Text(ErrorDisplayHelper.getErrorMessage(error))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            // Action Buttons
            HStack(spacing: 12) {
                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                if let retryAction = retryAction {
                    Button("Try Again") {
                        retryAction()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AVTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
        .background(AVTheme.surface.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    private func getErrorTitle() -> String {
        let category = ErrorHandler.getErrorCategory(error)
        
        switch category {
        case .aiService:
            return "AI Service Error"
        case .network:
            return "Connection Error"
        case .authentication:
            return "Sign-In Error"
        case .payment:
            return "Payment Error"
        case .username:
            return "Username Error"
        case .firebase:
            return "Service Error"
        case .generic:
            return "Something Went Wrong"
        }
    }
}

// MARK: - Compact Error Display
struct CompactErrorDisplayView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: ErrorDisplayHelper.getErrorIcon(error))
                    .foregroundStyle(ErrorDisplayHelper.swiftUIColor(for: error))
                Text(getErrorTitle())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            Text(ErrorDisplayHelper.getErrorMessage(error))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            
            if let retryAction = retryAction {
                HStack {
                    Spacer()
                    Button("Try Again") {
                        retryAction()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AVTheme.accent)
                }
            }
        }
        .padding(16)
        .background(AVTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func getErrorTitle() -> String {
        let category = ErrorHandler.getErrorCategory(error)
        
        switch category {
        case .aiService:
            return "AI Service Error"
        case .network:
            return "Connection Error"
        case .authentication:
            return "Sign-In Error"
        case .payment:
            return "Payment Error"
        case .username:
            return "Username Error"
        case .firebase:
            return "Service Error"
        case .generic:
            return "Error"
        }
    }
}

// MARK: - Loading Error Display
struct LoadingErrorDisplayView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: ErrorDisplayHelper.getErrorIcon(error))
                .font(.system(size: 32))
                .foregroundStyle(ErrorDisplayHelper.swiftUIColor(for: error))
            
            VStack(spacing: 8) {
                Text(getErrorTitle())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(ErrorDisplayHelper.getErrorMessage(error))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let retryAction = retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AVTheme.accent, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(AVTheme.surface.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func getErrorTitle() -> String {
        let category = ErrorHandler.getErrorCategory(error)
        
        switch category {
        case .aiService:
            return "AI Service Unavailable"
        case .network:
            return "No Connection"
        case .authentication:
            return "Sign-In Failed"
        case .payment:
            return "Payment Failed"
        case .username:
            return "Username Error"
        case .firebase:
            return "Service Unavailable"
        case .generic:
            return "Loading Failed"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ErrorDisplayView(
            error: NSError(domain: "AIIdeasService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Search limit reached"]),
            retryAction: { print("Retry tapped") },
            dismissAction: { print("Dismiss tapped") }
        )
        
        CompactErrorDisplayView(
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "No internet connection"]),
            retryAction: { print("Retry tapped") }
        )
        
        LoadingErrorDisplayView(
            error: NSError(domain: "StripePaymentService", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Payment failed"]),
            retryAction: { print("Retry tapped") }
        )
    }
    .padding()
    .background(AVTheme.gradient)
}
