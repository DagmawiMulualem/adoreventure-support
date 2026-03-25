//
//  RootView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct RootView: View {
    @State private var location = ""
    @State private var showingSubscriptionPrompt = false
    @State private var showingManageSubscription = false
    @State private var showingModelSelection = false
    @State private var showingProfileSettings = false
    @State private var showingTravelMap = false

    @State private var searchText = ""
    @State private var showAutocomplete = false
    @State private var showLocationError = false
    @State private var isNavigatingToCategories = false
    
    // Use the published property from FirebaseManager for reactive updates
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var placesService = PlacesAutocompleteService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Push the entire content down by adding top padding
                        Spacer()
                            .frame(height: 100)
                        
                        VStack(spacing: 16) {
                            // Responsive hero section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Discover Your")
                                    .responsiveTitleFont()
                                    .foregroundStyle(.white)
                                Text("Next")
                                    .responsiveTitleFont()
                                    .foregroundStyle(.white)
                                Text("Adventure")
                                    .responsiveTitleFont()
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .responsiveHorizontalPadding()
                            
                            // Add space after header
                            Spacer()
                                .frame(height: 2)
                            
                            // Subscription status indicator
                            HStack {
                                Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "magnifyingglass")
                                    .foregroundStyle(subscriptionManager.isSubscribed ? .yellow : .white.opacity(0.8))
                                Text(subscriptionManager.searchLimitMessage)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                Spacer()
                            }
                            .responsiveHorizontalPadding()
                            .onAppear {
                                searchText = location
                            }
                            
                            // Add space after search count
                            Spacer()
                                .frame(height: 1)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(AVTheme.accent)
                                    TextField("", text: $searchText, prompt: Text("Search by city or country only").foregroundStyle(Color(.secondaryLabel)))
                                        .textInputAutocapitalization(.words)
                                        .submitLabel(.go)
                                        .foregroundStyle(Color(.label))
                                        .onTapGesture {
                                            // Clear error when user taps on search field
                                            showLocationError = false
                                        }
                                        .onChange(of: searchText) { _, newValue in
                                            // Clear error when user starts typing
                                            if !newValue.isEmpty {
                                                showLocationError = false
                                            }
                                            
                                            showAutocomplete = !newValue.isEmpty
                                            if showAutocomplete {
                                                Task {
                                                    await placesService.searchPlaces(query: newValue)
                                                }
                                            } else {
                                                placesService.clearPredictions()
                                            }
                                        }
                                        .onSubmit {
                                            if !searchText.isEmpty {
                                                location = searchText
                                                showAutocomplete = false
                                                placesService.clearPredictions()
                                                showLocationError = false
                                            }
                                        }
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                
                                // Error message
                                if showLocationError {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.white)
                                            .font(.caption)
                                        Text("Please enter a location to continue")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                        Spacer()
                                    }
                                    .padding(.top, 8)
                                    .padding(.horizontal, 4)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                                
                                // Autocomplete suggestions
                                if showAutocomplete && (!placesService.predictions.isEmpty || placesService.isLoading) {
                                    PlacesAutocompleteView(
                                        searchText: $searchText,
                                        selectedLocation: $location,
                                        placesService: placesService
                                    ) { selectedLocation in
                                        self.location = selectedLocation
                                        self.searchText = selectedLocation
                                        self.showAutocomplete = false
                                        self.showLocationError = false
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .responsiveHorizontalPadding()
                            
                            // AI Model Selection Button
                            Button {
                                showingModelSelection = true
                            } label: {
                                HStack(spacing: 10) {
                                    // Brain icon
                                    ZStack {
                                        Circle()
                                            .fill(.white.opacity(0.2))
                                            .frame(width: 28, height: 28)
                                        
                                        Image(systemName: "brain.head.profile")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }
                                    
                                    // Model name
                                    Text(subscriptionManager.selectedModel.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.9))
                                    
                                    Spacer()
                                    
                                    // Chevron
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 18)
                            }
                            .responsiveHorizontalPadding()
                            
                            Button {
                                // Check if user has entered a location (either selected from autocomplete or typed)
                                if location.isEmpty && searchText.isEmpty {
                                    // Show error and shake animation
                                    showLocationError = true
                                    withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                                        // This will trigger a visual feedback
                                    }
                                } else {
                                    // Use searchText if location is empty but user has typed something
                                    if location.isEmpty && !searchText.isEmpty {
                                        location = searchText
                                    }
                                    // Navigate to categories
                                    isNavigatingToCategories = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Get Started").fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AVTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                            }
                            .responsiveHorizontalPadding()
                            .background(
                                NavigationLink(
                                    destination: CategoryGridView(location: location),
                                    isActive: $isNavigatingToCategories
                                ) {
                                    EmptyView()
                                }
                            )
                            
                            // Travel Map Button
                            HStack {
                                Spacer()
                                Button {
                                    print("🗺️ Travel Map button tapped!")
                                    showingTravelMap = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "globe")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                        Text("Travel Map")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 25)
                                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                                }
                                Spacer()
                            }
                            .responsiveHorizontalPadding()
                            
                            // Dynamic bottom spacing (guard against NaN from safe area)
                            GeometryReader { geometry in
                                let bottom = geometry.safeAreaInsets.bottom.sanitizedForLayout
                                let raw = bottom + 20
                                let h: CGFloat = raw.isFinite && !raw.isNaN ? max(40, raw) : 40
                                Color.clear.frame(height: h.sanitizedForLayout)
                            }
                            .frame(height: 0)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Text("Welcome, \(firebaseManager.currentDisplayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if subscriptionManager.isSubscribed {
                                Menu {
                                    Label("Premium Member ✨", systemImage: "crown.fill")
                                        .foregroundStyle(.yellow)
                                    
                                    Button {
                                        showingManageSubscription = true
                                    } label: {
                                        Label("Manage Subscription", systemImage: "creditcard.fill")
                                    }
                                } label: {
                                    Label("Premium Member ✨", systemImage: "crown.fill")
                                        .foregroundStyle(.yellow)
                                }
                            } else {
                                Label(subscriptionManager.searchLimitMessage, systemImage: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                            
                            NavigationLink {
                                BookmarksView()
                                    .environmentObject(firebaseManager)
                            } label: {
                                Label("Bookmarks", systemImage: "bookmark.fill")
                            }
                            
                            Button {
                                showingProfileSettings = true
                            } label: {
                                Label("Profile Settings", systemImage: "person.circle.fill")
                            }
                            
                            
                            
                            if !subscriptionManager.isSubscribed {
                                Button {
                                    showingSubscriptionPrompt = true
                                } label: {
                                    Label("Upgrade to Premium", systemImage: "crown.fill")
                                }
                                .foregroundStyle(.yellow)
                            }
                            
                            // Admin Panel (only visible to admins)
                            if subscriptionManager.isAdmin() {
                                Button {
                                    subscriptionManager.toggleAdminPanel()
                                } label: {
                                    Label("Admin Panel", systemImage: "wrench.and.screwdriver.fill")
                                }
                                .foregroundStyle(.purple)
                            }
                            
                            Divider()
                            
                            Button("Logout") {
                                firebaseManager.signOut()
                            }
                            .foregroundStyle(.red)
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .sheet(isPresented: $showingSubscriptionPrompt) {
                    SubscriptionPromptView()
                        .environmentObject(subscriptionManager)
                }
                .sheet(isPresented: $showingManageSubscription) {
                    ManageSubscriptionView()
                        .environmentObject(subscriptionManager)
                }
                .sheet(isPresented: $subscriptionManager.showAdminPanel) {
                    AdminPanelView()
                        .environmentObject(subscriptionManager)
                }
                .sheet(isPresented: $showingModelSelection) {
                    ModelSelectionPage()
                        .environmentObject(subscriptionManager)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showingProfileSettings) {
                    ProfileSettingsView()
                        .environmentObject(firebaseManager)
                }
                .sheet(isPresented: $showingTravelMap) {
                    TravelMapView()
                        .onAppear {
                            print("🗺️ Travel Map sheet appeared!")
                        }
                }

                

            }
        }
    }
}
