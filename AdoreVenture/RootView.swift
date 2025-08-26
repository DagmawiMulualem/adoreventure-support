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
    @State private var searchText = ""
    @State private var showAutocomplete = false

    @State private var username = "User"
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var placesService = PlacesAutocompleteService()

    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
            
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 60)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Discover Your")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Next")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Adventure")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                        Text("Find perfect date ideas, birthday celebrations, travel activities, and local experiences tailored just for you.")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Subscription status indicator
                        HStack {
                            Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "magnifyingglass")
                                .foregroundStyle(subscriptionManager.isSubscribed ? .yellow : .white.opacity(0.8))
                            Text(subscriptionManager.searchLimitMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .onAppear {
                            searchText = location
                        }

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(AVTheme.accent)
                                TextField("Enter location", text: $searchText)
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.go)
                                    .foregroundStyle(.primary)
                                    .onChange(of: searchText) { _, newValue in
                                        if newValue != location {
                                            showAutocomplete = !newValue.isEmpty
                                            if showAutocomplete {
                                                Task {
                                                    await placesService.searchPlaces(query: newValue)
                                                }
                                            } else {
                                                placesService.clearPredictions()
                                            }
                                        }
                                    }
                                    .onSubmit {
                                        if !searchText.isEmpty {
                                            location = searchText
                                            showAutocomplete = false
                                            placesService.clearPredictions()
                                        }
                                    }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            
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
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 24)

                        NavigationLink {
                            CategoryGridView(location: location)
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
                        .padding(.horizontal, 24)

                        NavigationLink {
                            CategoryGridView(location: location)
                        } label: {
                            Text("Browse Categories")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(.white, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 24)

                        // Bookmarks button
                        NavigationLink {
                            BookmarksView()
                                .environmentObject(firebaseManager)
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("My Bookmarks")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AVTheme.accent.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 24)

                        Image(systemName: "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 6)

                        Spacer().frame(height: 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Text("Welcome, \(username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if subscriptionManager.isSubscribed {
                            Label("Premium Member ✨", systemImage: "crown.fill")
                                .foregroundStyle(.yellow)
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
                        

                        
                        if !subscriptionManager.isSubscribed {
                            Button {
                                showingSubscriptionPrompt = true
                            } label: {
                                Label("Upgrade to Premium", systemImage: "crown.fill")
                            }
                            .foregroundStyle(.yellow)
                        }
                        
                        // Toggle subscription for testing
                        Button {
                            Task {
                                await subscriptionManager.toggleSubscriptionForTesting()
                            }
                        } label: {
                            Label("Toggle Premium (Test)", systemImage: "wrench.fill")
                        }
                        .foregroundStyle(.orange)
                        
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

            .onAppear {
                Task {
                    username = await firebaseManager.fetchUsername()
                }
            }
        }
    }
}
