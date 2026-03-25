//
//  CategoryGridView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct CategoryGridView: View {
    let location: String
    @State private var selection: AVCategory? = .date
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // Responsive grid columns with proper spacing
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section with responsive spacing
                VStack(alignment: .leading, spacing: 8) {
                    Text("What Are You Looking For?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Choose a category to discover personalized activity suggestions")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Category grid with proper spacing
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AVCategory.allCases) { cat in
                        CategoryCard(category: cat, selected: selection == cat)
                            .onTapGesture { selection = cat }
                    }
                }
                .padding(.top, 8)

                // See Ideas button with proper spacing
                NavigationLink {
                    PreferencesView(
                        location: location,
                        category: selection ?? .date
                    )
                    .environmentObject(firebaseManager)
                    .environmentObject(subscriptionManager)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AVTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryCard: View {
    let category: AVCategory
    let selected: Bool
    
    // Card height
    private let cardHeight: CGFloat = 140
    
    // Icon size
    private let iconSize: CGFloat = 16
    
    // Icon container size
    private let iconContainerSize: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon at the top
            Image(systemName: category.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(AVTheme.accent)
                .frame(width: iconContainerSize, height: iconContainerSize)
                .background(AVTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(category.subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0) // Pushes content up so height matches
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(selected ? AVTheme.accent : .clear, lineWidth: 2)
        )
        .frame(height: cardHeight) // Uniform size
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}
