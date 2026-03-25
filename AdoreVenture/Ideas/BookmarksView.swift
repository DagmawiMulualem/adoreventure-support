//
//  BookmarksView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @State private var searchText = ""

    // Keep a copy so we can restore on disappear (optional)
    private let previousStandard = UINavigationBar.appearance().standardAppearance
    private let previousScroll = UINavigationBar.appearance().scrollEdgeAppearance
    private let previousCompact = UINavigationBar.appearance().compactAppearance

    var filteredBookmarks: [AVIdea] {
        if searchText.isEmpty {
            return firebaseManager.bookmarkedIdeas
        } else {
            return firebaseManager.bookmarkedIdeas.filter { idea in
                idea.title.localizedCaseInsensitiveContains(searchText) ||
                idea.place.localizedCaseInsensitiveContains(searchText) ||
                idea.blurb.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()

                if firebaseManager.bookmarkedIdeas.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.7))

                        Text("No Bookmarks Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Start exploring activities and tap the bookmark icon to save your favorites!")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search bookmarks...", text: $searchText)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 20)

                            if filteredBookmarks.isEmpty && !searchText.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.white.opacity(0.6))

                                    Text("No matches found")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)

                                    Text("Try searching with different keywords")
                                        .font(.body)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.top, 60)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredBookmarks) { idea in
                                        BookmarkCard(idea: idea)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)                 // ⬅️ keep gradient visible behind the bar

            .toolbarColorScheme(.dark, for: .navigationBar)                 // ⬅️ helps keep bar items light
            .onAppear {                                                     // ⬅️ force title text to white
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }

        }
    }
}


struct BookmarkCard: View {
    let idea: AVIdea
    @EnvironmentObject var firebaseManager: FirebaseManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(String(format: "%.1f", idea.rating), systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
                Spacer()
                Button {
                    Task {
                        await firebaseManager.toggleBookmark(for: idea)
                    }
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.title3)
                        .foregroundStyle(AVTheme.accent)
                }
                .buttonStyle(.plain)
            }

            Text(idea.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(idea.blurb)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 14) {
                Label(idea.place, systemImage: "mappin.circle")
                Label(idea.duration, systemImage: "clock")
                Label(idea.priceRange, systemImage: "dollarsign.circle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Tags
            if !idea.tags.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 6)
                ], spacing: 6) {
                    ForEach(idea.tags.prefix(4), id: \.self) { tag in
                        AVTag(text: tag)
                    }
                }
            }

            // Learn More button
            NavigationLink {
                IdeaDetailView(idea: idea)
                    .environmentObject(firebaseManager)
            } label: {
                Text("View Details")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AVTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    BookmarksView()
        .environmentObject(FirebaseManager.shared)
}
