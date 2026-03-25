//
//  ProfileSettingsView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/24/25.
//

import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    

    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)
                        
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)
                            
                            Text("Profile Settings")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Customize your profile and preferences")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Profile Form Card
                        VStack(spacing: 20) {
                            // Display Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(AVTheme.accent)
                                        .frame(width: 20)
                                    
                                    TextField("Enter display name", text: $displayName)
                                        .textContentType(.name)
                                        .autocapitalization(.words)
                                        .disableAutocorrection(true)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(AVTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Save Button
                            Button {
                                Task {
                                    await saveDisplayName()
                                }
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text(isLoading ? "Saving..." : "Save Changes")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(displayName.count >= 2 ? AVTheme.accent : AVTheme.accent.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                            }
                            .disabled(displayName.count < 2 || isLoading)
                        }
                        .padding(24)
                        .background(AVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Profile Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .alert("Profile Update", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadCurrentDisplayName()
            }
        }
    }
    
    private func loadCurrentDisplayName() {
        Task {
            displayName = await firebaseManager.fetchDisplayName()
        }
    }
    
    private func saveDisplayName() async {
        guard displayName.count >= 2 else { return }
        
        await MainActor.run { 
            isLoading = true 
            alertMessage = ""
        }
        
        do {
            let success = await firebaseManager.updateDisplayName(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isLoading = false
                if success {
                    alertMessage = "Display name updated successfully!"
                    showAlert = true
                    
                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                } else {
                    alertMessage = firebaseManager.errorMessage ?? "Failed to update display name"
                    showAlert = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "An error occurred while updating display name"
                showAlert = true
            }
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(FirebaseManager.shared)
}
