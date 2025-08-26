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
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What Are You Looking For?")
                    .font(.system(size: 30, weight: .bold))
                Text("Choose a category to discover personalized activity suggestions")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AVCategory.allCases) { cat in
                        CategoryCard(category: cat, selected: selection == cat)
                            .onTapGesture { selection = cat }
                    }
                }

                NavigationLink {
                    IdeasListView(
                        location: location,
                        category: selection ?? .date,
                        ideas: [],
                        autoFetch: true
                    )
                    .environmentObject(firebaseManager)
                    .environmentObject(subscriptionManager)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("See Ideas").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AVTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryCard: View {
    let category: AVCategory
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 22, weight: .semibold))
                .padding(12)
                .background(AVTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(category.rawValue).font(.headline)
            Text(category.subtitle).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minHeight: 130)
        .avCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? AVTheme.accent : .clear, lineWidth: 2)
        )
    }
}
