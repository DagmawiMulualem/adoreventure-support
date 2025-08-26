//
//  ForgotPasswordView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @EnvironmentObject var firebaseManager: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)
                        
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reset")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Password")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        
                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Form Card
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundStyle(AVTheme.accent)
                                        .frame(width: 20)
                                    
                                    TextField("Enter your email", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(AVTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Reset Password Button
                            Button {
                                if email.isEmpty {
                                    alertMessage = "Please enter your email address"
                                    showAlert = true
                                } else {
                                    Task {
                                        let success = await firebaseManager.resetPassword(email: email)
                                        await MainActor.run {
                                            if success {
                                                isSuccess = true
                                                alertMessage = "Password reset email sent! Check your inbox."
                                            } else {
                                                alertMessage = firebaseManager.errorMessage ?? "Failed to send reset email"
                                            }
                                            showAlert = true
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if firebaseManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(firebaseManager.isLoading ? "Sending..." : "Send Reset Link")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AVTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                            }
                            .disabled(firebaseManager.isLoading)
                            
                            // Back to Login
                            Button("Back to Login") {
                                dismiss()
                            }
                            .font(.subheadline)
                            .foregroundStyle(AVTheme.accent)
                        }
                        .padding(24)
                        .background(AVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.6), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(isSuccess ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {
                    if isSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(FirebaseManager.shared)
}
