//
//  AchievementsView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

private func achievementProgressFraction(_ achievement: Achievement) -> Double {
    guard achievement.requirement > 0 else { return 0 }
    return (Double(achievement.progress) / Double(achievement.requirement)).avClampedUnitInterval
}

struct AchievementsView: View {
    @ObservedObject var travelMapService: TravelMapService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: AchievementCategory? = nil
    
    var filteredAchievements: [Achievement] {
        if let category = selectedCategory {
            return travelMapService.achievements.filter { $0.category == category }
        } else {
            return travelMapService.achievements
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Achievement Stats
                        AchievementStatsView(travelMapService: travelMapService)
                        
                        // Category Filter
                        CategoryFilterView(selectedCategory: $selectedCategory)
                        
                        // Achievements Grid
                        AchievementsGridView(achievements: filteredAchievements)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Achievement Stats View
struct AchievementStatsView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var unlockedCount: Int {
        travelMapService.achievements.filter { $0.isUnlocked }.count
    }
    
    var totalCount: Int {
        travelMapService.achievements.count
    }
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Achievement Progress")
                .font(.headline)
                .foregroundStyle(.white)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progress.avClampedUnitInterval)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)
                
                VStack(spacing: 4) {
                    Text("\(unlockedCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("of \(totalCount)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            Text("\(Int(progress.avClampedUnitInterval * 100))% Complete")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Category Filter View
struct CategoryFilterView: View {
    @Binding var selectedCategory: AchievementCategory?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterButton(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    color: .white
                ) {
                    selectedCategory = nil
                }
                
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    FilterButton(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        color: category.color
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Achievements Grid View
struct AchievementsGridView: View {
    let achievements: [Achievement]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(achievements) { achievement in
                AchievementCardView(achievement: achievement)
            }
        }
    }
}

// MARK: - Achievement Card View
struct AchievementCardView: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.category.color : Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundStyle(achievement.isUnlocked ? .white : .gray)
            }
            
            VStack(spacing: 8) {
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Progress bar for locked achievements
                if !achievement.isUnlocked {
                    VStack(spacing: 4) {
                        ProgressView(value: achievementProgressFraction(achievement))
                            .progressViewStyle(LinearProgressViewStyle(tint: achievement.category.color))
                            .scaleEffect(y: 1.5)
                        
                        Text("\(achievement.progress)/\(achievement.requirement)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    // Unlocked date
                    if let unlockedDate = achievement.unlockedDate {
                        Text("Unlocked \(formatDate(unlockedDate))")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    achievement.isUnlocked ? achievement.category.color : Color.clear,
                    lineWidth: 2
                )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    AchievementsView(travelMapService: TravelMapService.shared)
}
