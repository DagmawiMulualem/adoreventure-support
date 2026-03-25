//
//  ErrorHandler.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/26/25.
//

import Foundation

struct ErrorHandler {
    
    // MARK: - AI Service Errors
    static func getAIServiceErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError

        // Firebase Callable → Python backend (Render)
        if nsError.domain == "com.firebase.functions" {
            switch nsError.code {
            case 13: // INTERNAL — backend error, timeout, or bad deploy
                return "Our idea server is temporarily unavailable. Please try again in a moment."
            case 4, 14: // deadline / unavailable
                return "Request timed out. Please try again."
            case 3:
                return "Invalid request. Please try a different search."
            default:
                return "AI service error. Please try again."
            }
        }
        
        if nsError.domain == "AIIdeasService" {
            switch nsError.code {
            case -1:
                return "Invalid response from AI service. Please try again."
            case -2:
                return "AI service temporarily unavailable. Please try again in a moment."
            case -3:
                return "Search limit reached. Please upgrade to Premium for unlimited searches."
            case -4:
                return "Request timed out. Please try again."
            case -5:
                return "Invalid location. Please check your input and try again."
            case -6:
                return "Data serialization error. Please check your input and try again."
            case -7:
                return "No ideas found for this location and category. Please try a different search."
            case -8:
                return "Failed to generate ideas after multiple attempts. Please try again."
            case -9:
                return "Invalid backend configuration. Please contact support."
            case -10:
                return "Failed to prepare request. Please try again."
            case -11:
                return "Invalid response from server. Please try again."
            case -12:
                return "Backend service error. Please try again in a moment."
            default:
                return "AI service error. Please try again."
            }
        }
        
        return "Something went wrong. Please try again."
    }
    
    // MARK: - Network Errors
    static func getNetworkErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Please check your Wi-Fi or cellular data and try again."
            case NSURLErrorTimedOut:
                return "Request timed out. Please check your connection and try again."
            case NSURLErrorCannotFindHost:
                return "Unable to reach our servers. Please try again later."
            case NSURLErrorCannotConnectToHost:
                return "Connection failed. Please check your internet and try again."
            case NSURLErrorNetworkConnectionLost:
                return "Connection lost. Please try again."
            default:
                return "Network error. Please check your connection and try again."
            }
        }
        
        return getGenericErrorMessage(error)
    }
    
    // MARK: - Authentication Errors
    static func getAuthErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17020: // FIRAuthErrorCodeNetworkError
                return "Network error during sign-in. Please check your connection and try again."
            case 17011: // FIRAuthErrorCodeInvalidEmail
                return "Please enter a valid email address."
            case 17009: // FIRAuthErrorCodeWrongPassword
                return "Incorrect password. Please try again."
            case 17008: // FIRAuthErrorCodeUserNotFound
                return "No account found with this email. Please check your email or create a new account."
            case 17026: // FIRAuthErrorCodeWeakPassword
                return "Password is too weak. Please choose a stronger password."
            case 17007: // FIRAuthErrorCodeEmailAlreadyInUse
                return "An account with this email already exists. Please sign in instead."
            case 17012: // FIRAuthErrorCodeTooManyRequests
                return "Too many sign-in attempts. Please wait a moment and try again."
            case 17005: // FIRAuthErrorCodeUserDisabled
                return "This account has been disabled. Please contact support."
            default:
                return "Sign-in failed. Please try again."
            }
        }
        
        return getGenericErrorMessage(error)
    }
    
    // MARK: - Payment Errors
    static func getPaymentErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "StripePaymentService" {
            switch nsError.code {
            case 1001:
                return "Payment was cancelled. You can try again anytime."
            case 1002:
                return "Payment failed. Please check your payment method and try again."
            case 1003:
                return "Your card was declined. Please try a different payment method."
            case 1004:
                return "Payment processing error. Please try again in a moment."
            case 1005:
                return "Subscription setup failed. Please try again."
            default:
                return "Payment error. Please try again or contact support."
            }
        }
        
        return getGenericErrorMessage(error)
    }
    
    // MARK: - Username Errors
    static func getUsernameErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "FirebaseManager" {
            switch nsError.code {
            case 2001:
                return "Username is already taken. Please choose a different username."
            case 2002:
                return "Username contains invalid characters. Please use only letters, numbers, and underscores."
            case 2003:
                return "Username is too short. Please use at least 3 characters."
            case 2004:
                return "Username is too long. Please use 20 characters or less."
            case 2005:
                return "Unable to check username availability. Please try again."
            case 2006:
                return "Failed to save username. Please try again."
            default:
                return "Username error. Please try again."
            }
        }
        
        return getGenericErrorMessage(error)
    }
    
    // MARK: - Firebase Errors
    static func getFirebaseErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "FirebaseFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // Permission denied
                return "Access denied. Please sign in again."
            case 3: // Invalid argument
                return "Invalid data. Please try again."
            case 13: // Resource exhausted
                return "Service temporarily unavailable. Please try again later."
            case 14: // Failed precondition
                return "Operation not allowed. Please try again."
            case 16: // Unavailable
                return "Service unavailable. Please try again later."
            default:
                return "Database error. Please try again."
            }
        }
        
        return getGenericErrorMessage(error)
    }
    
    // MARK: - Generic Error
    static func getGenericErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        // Check for common error patterns
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("timeout") || errorMessage.contains("timed out") {
            return "Request timed out. Please try again."
        } else if errorMessage.contains("network") || errorMessage.contains("connection") {
            return "Network error. Please check your connection and try again."
        } else if errorMessage.contains("server") || errorMessage.contains("service") {
            return "Service temporarily unavailable. Please try again in a moment."
        } else if errorMessage.contains("permission") || errorMessage.contains("access") {
            return "Access denied. Please try again or contact support."
        } else if errorMessage.contains("invalid") || errorMessage.contains("malformed") {
            return "Invalid data. Please try again."
        } else if errorMessage.contains("not found") || errorMessage.contains("missing") {
            return "Resource not found. Please try again."
        } else if errorMessage.contains("cancelled") || errorMessage.contains("canceled") {
            return "Operation was cancelled."
        } else {
            return "Something went wrong. Please try again."
        }
    }
    
    // MARK: - Error Categories
    static func getErrorCategory(_ error: Error) -> ErrorCategory {
        let nsError = error as NSError
        
        // AI Service errors
        if nsError.domain == "AIIdeasService" {
            return .aiService
        }
        
        // Network errors
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        
        // Authentication errors
        if nsError.domain == "FIRAuthErrorDomain" {
            return .authentication
        }
        
        // Payment errors
        if nsError.domain == "StripePaymentService" {
            return .payment
        }
        
        // Username errors
        if nsError.domain == "FirebaseManager" && nsError.code >= 2000 {
            return .username
        }
        
        // Firebase errors
        if nsError.domain == "FirebaseFirestoreErrorDomain" {
            return .firebase
        }

        // Firebase Callable (getIdeas / getSingleIdea → Render backend)
        if nsError.domain == "com.firebase.functions" {
            return .aiService
        }
        
        return .generic
    }
    
    // MARK: - Error Icons
    static func getErrorIcon(_ category: ErrorCategory) -> String {
        switch category {
        case .aiService:
            return "brain.head.profile"
        case .network:
            return "wifi.slash"
        case .authentication:
            return "person.crop.circle.badge.exclamationmark"
        case .payment:
            return "creditcard.trianglebadge.exclamationmark"
        case .username:
            return "at.badge.plus"
        case .firebase:
            return "flame"
        case .generic:
            return "exclamationmark.triangle.fill"
        }
    }
    
    // MARK: - Error Colors
    static func getErrorColor(_ category: ErrorCategory) -> String {
        switch category {
        case .aiService:
            return "orange"
        case .network:
            return "blue"
        case .authentication:
            return "red"
        case .payment:
            return "purple"
        case .username:
            return "green"
        case .firebase:
            return "orange"
        case .generic:
            // Not a catalog name — use semantic colors via ErrorDisplayHelper.swiftUIColor(for:)
            return "gray"
        }
    }
}

// MARK: - Error Categories
enum ErrorCategory {
    case aiService
    case network
    case authentication
    case payment
    case username
    case firebase
    case generic
}

// MARK: - Error Display Helper
struct ErrorDisplayHelper {
    static func getErrorMessage(_ error: Error) -> String {
        let category = ErrorHandler.getErrorCategory(error)
        
        switch category {
        case .aiService:
            return ErrorHandler.getAIServiceErrorMessage(error)
        case .network:
            return ErrorHandler.getNetworkErrorMessage(error)
        case .authentication:
            return ErrorHandler.getAuthErrorMessage(error)
        case .payment:
            return ErrorHandler.getPaymentErrorMessage(error)
        case .username:
            return ErrorHandler.getUsernameErrorMessage(error)
        case .firebase:
            return ErrorHandler.getFirebaseErrorMessage(error)
        case .generic:
            return ErrorHandler.getGenericErrorMessage(error)
        }
    }
    
    static func getErrorIcon(_ error: Error) -> String {
        let category = ErrorHandler.getErrorCategory(error)
        return ErrorHandler.getErrorIcon(category)
    }
    
    static func getErrorColor(_ error: Error) -> String {
        let category = ErrorHandler.getErrorCategory(error)
        return ErrorHandler.getErrorColor(category)
    }
}
