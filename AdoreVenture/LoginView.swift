//
//  LoginView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showForgotPassword = false
    @State private var useUsername = false // Toggle between email and username
    @EnvironmentObject var firebaseManager: FirebaseManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)
                        
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome to")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            Text("AdoreVenture")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        
                        Text("Sign in to discover your next adventure and save your favorite activities.")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Login Form Card
                        VStack(spacing: 20) {
                            // Login Method Toggle
                            HStack {
                                // Email Button
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        useUsername = false
                                    }
                                } label: {
                                    let isEmailSelected = !useUsername
                                    
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                        Text("Email")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(isEmailSelected ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isEmailSelected ? AVTheme.accent : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                
                                // Username Button
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        useUsername = true
                                    }
                                } label: {
                                    let isUsernameSelected = useUsername
                                    
                                    HStack {
                                        Image(systemName: "person.fill")
                                        Text("Username")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(isUsernameSelected ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isUsernameSelected ? AVTheme.accent : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .padding(4)
                            .background(AVTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            
                            // Email Field (shown when useUsername is false)
                            if !useUsername {
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
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Username Field (shown when useUsername is true)
                            if useUsername {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Username")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(AVTheme.accent)
                                            .frame(width: 20)
                                        
                                        TextField("Enter your username", text: $username)
                                            .textContentType(.username)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 18)
                                    .background(AVTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(AVTheme.accent)
                                        .frame(width: 20)
                                    
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                            .textContentType(.password)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .textContentType(.password)
                                    }
                                    
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(AVTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Forgot Password
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showForgotPassword = true
                                }
                                .font(.subheadline)
                                .foregroundStyle(AVTheme.accent)
                            }
                            
                            // Sign In Button
                            Button {
                                print("🔐 Login: Sign in button tapped")
                                
                                // Validate input based on login method
                                if useUsername {
                                    if username.isEmpty || password.isEmpty {
                                        alertMessage = "Please enter both username and password"
                                        showAlert = true
                                        return
                                    }
                                } else {
                                    if email.isEmpty || password.isEmpty {
                                        alertMessage = "Please enter both email and password"
                                        showAlert = true
                                        return
                                    }
                                }
                                
                                Task {
                                    print("🔐 Login: Starting Firebase sign in...")
                                    
                                    let success: Bool
                                    if useUsername {
                                        success = await firebaseManager.signInWithUsername(username: username, password: password)
                                    } else {
                                        success = await firebaseManager.signIn(email: email, password: password)
                                    }
                                    
                                    await MainActor.run {
                                        if !success {
                                            alertMessage = firebaseManager.errorMessage ?? "Login failed"
                                            showAlert = true
                                        } else {
                                            print("🔐 Login: Sign in successful, navigating to main app")
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
                                        Image(systemName: "arrow.right")
                                    }
                                    Text(firebaseManager.isLoading ? "Signing In..." : "Sign In")
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
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.secondary.opacity(0.3))
                                Text("or")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.secondary.opacity(0.3))
                            }
                            
                            // Social Login Buttons
                            VStack(spacing: 12) {
                                Button {
                                    Task {
                                        print("🔐 Login: Apple Sign-In button tapped")
                                        let success = await firebaseManager.signInWithApple()
                                        if !success {
                                            alertMessage = firebaseManager.errorMessage ?? "Apple Sign-In failed"
                                            showAlert = true
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "applelogo")
                                        Text("Continue with Apple")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AVTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .disabled(firebaseManager.isLoading)
                                
                                Button {
                                    Task {
                                        print("🔐 Login: Google Sign-In button tapped")
                                        let success = await firebaseManager.signInWithGoogle()
                                        if !success {
                                            alertMessage = firebaseManager.errorMessage ?? "Google Sign-In failed"
                                            showAlert = true
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "globe")
                                        Text("Continue with Google")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AVTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .disabled(firebaseManager.isLoading)
                            }
                            
                            // Sign Up Link
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundStyle(.secondary)
                                Button("Sign Up") {
                                    isSignUp = true
                                }
                                .foregroundStyle(AVTheme.accent)
                                .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            

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
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isSignUp) {
                SignUpView()
                    .environmentObject(firebaseManager)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(firebaseManager)
            }
            .alert("Login Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

struct SignUpView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
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
                            Text("Join")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            Text("AdoreVenture")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        
                        Text("Create an account to start discovering amazing adventures and save your favorites.")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Sign Up Form Card
                        VStack(spacing: 20) {
                            // Username Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(AVTheme.accent)
                                        .frame(width: 20)
                                    
                                    TextField("Choose a username", text: $username)
                                        .textContentType(.username)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(AVTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
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
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(AVTheme.accent)
                                        .frame(width: 20)
                                    
                                    if showPassword {
                                        TextField("Create a password", text: $password)
                                            .textContentType(.newPassword)
                                    } else {
                                        SecureField("Create a password", text: $password)
                                            .textContentType(.newPassword)
                                    }
                                    
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(AVTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(AVTheme.accent)
                                        .frame(width: 20)
                                    
                                    if showConfirmPassword {
                                        TextField("Confirm your password", text: $confirmPassword)
                                            .textContentType(.newPassword)
                                    } else {
                                        SecureField("Confirm your password", text: $confirmPassword)
                                            .textContentType(.newPassword)
                                    }
                                    
                                    Button {
                                        showConfirmPassword.toggle()
                                    } label: {
                                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(AVTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Sign Up Button
                            Button {
                                print("🔐 SignUp: Sign up button tapped")
                                if username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty {
                                    alertMessage = "Please fill in all fields"
                                    showAlert = true
                                } else if password != confirmPassword {
                                    alertMessage = "Passwords do not match"
                                    showAlert = true
                                } else if password.count < 6 {
                                    alertMessage = "Password must be at least 6 characters"
                                    showAlert = true
                                } else if username.count < 3 {
                                    alertMessage = "Username must be at least 3 characters"
                                    showAlert = true
                                } else {
                                    Task {
                                        print("🔐 SignUp: Starting Firebase sign up...")
                                        let success = await firebaseManager.signUp(email: email, username: username, password: password)
                                        await MainActor.run {
                                            if success {
                                                print("🔐 SignUp: Sign up successful, closing sheet")
                                                dismiss() // Close signup sheet
                                            } else {
                                                alertMessage = firebaseManager.errorMessage ?? "Sign up failed"
                                                showAlert = true
                                            }
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
                                        Image(systemName: "person.badge.plus")
                                    }
                                    Text(firebaseManager.isLoading ? "Creating Account..." : "Create Account")
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
                            
                            // Terms and Conditions
                            Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            // Sign In Link
                            HStack {
                                Text("Already have an account?")
                                    .foregroundStyle(.secondary)
                                Button("Sign In") {
                                    dismiss()
                                }
                                .foregroundStyle(AVTheme.accent)
                                .fontWeight(.semibold)
                            }
                            .font(.subheadline)
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
            .alert("Sign Up Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(FirebaseManager.shared)
}
