//
//  TravelMapView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct TravelMapView: View {
    @StateObject private var travelMapService = TravelMapService.shared
    @State private var selectedCountry: Country?
    @State private var showingCountryDetail = false
    @State private var showingAchievements = false
    @State private var showingProgressStats = false
    @State private var selectedStatusFilter: TravelStatus? = nil
    @State private var showingShareOptions = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Country Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Country")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            CountryPickerView(
                                selectedCountry: $selectedCountry,
                                travelMapService: travelMapService
                            )
                            .onChange(of: selectedCountry) { oldValue, newValue in
                                if newValue != nil {
                                    showingCountryDetail = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Map View - Display Only
                        VStack(spacing: 8) {
                            HStack {
                                Text("Travel Map")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Text("View your travels")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            InteractiveTravelMapView(
                                travelMapService: travelMapService,
                                selectedCountry: $selectedCountry,
                                showingCountryDetail: $showingCountryDetail,
                                isInteractive: false // Make map display-only
                            )
                            .frame(height: 500)
                            .background(Color.black.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        }
                        
                        // Quick Stats Cards
                        QuickStatsView(travelMapService: travelMapService)
                        
                        // Status Filter Buttons
                        StatusFilterView(selectedStatus: $selectedStatusFilter)
                        
                        // Countries List
                        CountriesListView(
                            travelMapService: travelMapService,
                            selectedStatus: selectedStatusFilter
                        )
                        
                        // Recent Achievements
                        RecentAchievementsView(travelMapService: travelMapService)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Travel Map")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingProgressStats = true
                        } label: {
                            Label("Progress Stats", systemImage: "chart.bar.fill")
                        }
                        
                        Button {
                            showingAchievements = true
                        } label: {
                            Label("Achievements", systemImage: "trophy.fill")
                        }
                        
                        Divider()
                        
                        Button {
                            showingShareOptions = true
                        } label: {
                            Label("Share Map", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCountryDetail) {
            if let country = selectedCountry {
                CountryDetailView(country: country, travelMapService: travelMapService)
            }
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView(travelMapService: travelMapService)
        }
        .sheet(isPresented: $showingProgressStats) {
            ProgressStatsView(travelMapService: travelMapService)
        }
        .sheet(isPresented: $showingShareOptions) {
            ShareOptionsView(travelMapService: travelMapService)
        }
        .onAppear {
            Task {
                await travelMapService.setupUserData()
            }
        }
    }
    
}

// MARK: - Progress Header View
struct ProgressHeaderView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var body: some View {
        VStack(spacing: 16) {
            // World Progress
            VStack(spacing: 8) {
                Text("World Progress")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: travelMapService.travelStatistics.worldProgress.avClampedUnitInterval)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: travelMapService.travelStatistics.worldProgress)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(travelMapService.travelStatistics.worldProgress.avClampedUnitInterval * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("\(travelMapService.travelStatistics.visitedLocations)/\(travelMapService.travelStatistics.totalLocations)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            
            // Continent Progress
            ContinentProgressView(travelMapService: travelMapService)
        }
        .padding(20)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Continent Progress View
struct ContinentProgressView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Continent")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Continent.allCases, id: \.self) { continent in
                    let progress = travelMapService.travelStatistics.continentProgress[continent] ?? 0
                    let visitedCount = travelMapService.getCountries(in: continent).filter { $0.travelStatus == .visited }.count
                    let totalCount = travelMapService.getCountries(in: continent).count
                    
                    ContinentProgressCard(
                        continent: continent,
                        progress: progress,
                        visitedCount: visitedCount,
                        totalCount: totalCount
                    )
                }
            }
        }
    }
}

// MARK: - Continent Progress Card
struct ContinentProgressCard: View {
    let continent: Continent
    let progress: Double
    let visitedCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: continent.icon)
                    .foregroundStyle(continent.color)
                Text(continent.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            ProgressView(value: progress.avClampedUnitInterval)
                .progressViewStyle(LinearProgressViewStyle(tint: continent.color))
                .scaleEffect(y: 2)
            
            Text("\(visitedCount)/\(totalCount)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Stats View
struct QuickStatsView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var body: some View {
        HStack(spacing: 16) {
            TravelStatCard(
                title: "Visited",
                count: travelMapService.travelStatistics.visitedLocations,
                color: .green,
                icon: "checkmark.circle.fill"
            )
            
            TravelStatCard(
                title: "Wishlist",
                count: travelMapService.travelStatistics.wishlistCountries + travelMapService.travelStatistics.wishlistStates,
                color: .blue,
                icon: "heart.fill"
            )
            
            TravelStatCard(
                title: "Achievements",
                count: travelMapService.travelStatistics.achievements.count,
                color: .orange,
                icon: "trophy.fill"
            )
        }
    }
}

// MARK: - Travel Stat Card
struct TravelStatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Status Filter View
struct StatusFilterView: View {
    @Binding var selectedStatus: TravelStatus?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterButton(
                    title: "All",
                    isSelected: selectedStatus == nil,
                    color: .white
                ) {
                    selectedStatus = nil
                }
                
                ForEach(TravelStatus.allCases, id: \.self) { status in
                    FilterButton(
                        title: status.displayName,
                        isSelected: selectedStatus == status,
                        color: status.color
                    ) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? color : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Countries List View
struct CountriesListView: View {
    @ObservedObject var travelMapService: TravelMapService
    let selectedStatus: TravelStatus?
    
    var filteredCountries: [Country] {
        if let status = selectedStatus {
            return travelMapService.getCountries(by: status)
        } else {
            return travelMapService.countries.filter { $0.travelStatus != .untouched }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Countries")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(filteredCountries.count) countries")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            LazyVStack(spacing: 12) {
                ForEach(filteredCountries.prefix(10)) { country in
                    CountryRowView(country: country, travelMapService: travelMapService)
                }
                
                if filteredCountries.count > 10 {
                    Button("Show All \(filteredCountries.count) Countries") {
                        // Show full list
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Country Row View
struct CountryRowView: View {
    let country: Country
    @ObservedObject var travelMapService: TravelMapService
    @State private var showingStatusMenu = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Country flag/icon placeholder
            Image(systemName: country.continent.icon)
                .font(.title2)
                .foregroundStyle(country.continent.color)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(country.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                HStack {
                    Image(systemName: country.statusIcon)
                        .font(.caption)
                        .foregroundStyle(country.statusColor)
                    
                    Text(country.travelStatus.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    if let visitDate = country.formattedVisitDate {
                        Text("• \(visitDate)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            Menu {
                ForEach(TravelStatus.allCases, id: \.self) { status in
                    Button {
                        Task {
                            await travelMapService.updateCountryStatus(country, status: status)
                        }
                    } label: {
                        Label(status.displayName, systemImage: status.icon)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recent Achievements View
struct RecentAchievementsView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var recentAchievements: [Achievement] {
        travelMapService.achievements
            .filter { $0.isUnlocked }
            .sorted { ($0.unlockedDate ?? Date.distantPast) > ($1.unlockedDate ?? Date.distantPast) }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        if !recentAchievements.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent Achievements")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button("View All") {
                        // Show all achievements
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(recentAchievements) { achievement in
                        AchievementRowView(achievement: achievement)
                    }
                }
            }
        }
    }
}

// MARK: - Achievement Row View
struct AchievementRowView: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(achievement.category.color)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Country Picker View
struct CountryPickerView: View {
    @Binding var selectedCountry: Country?
    @ObservedObject var travelMapService: TravelMapService
    @State private var searchText = ""
    @State private var showingPicker = false
    @State private var showingCustomInput = false
    @State private var customCountryName = ""
    @State private var isAddingCountry = false
    
    var filteredCountries: [Country] {
        if searchText.isEmpty {
            return travelMapService.countries.sorted { $0.name < $1.name }
        } else {
            return travelMapService.countries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.name < $1.name }
        }
    }
    
    // Helper function to create and add a custom country with geocoding
    private func createCustomCountry(name: String) async -> Country? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        
        // Use the service to add the country (with geocoding)
        return await travelMapService.addCustomCountry(name: trimmedName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search/Select Button
            Button {
                showingPicker = true
            } label: {
                HStack {
                    if let country = selectedCountry {
                        HStack(spacing: 8) {
                            Image(systemName: country.id.hasPrefix("custom_") ? "plus.circle.fill" : "globe")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                Text(country.id.hasPrefix("custom_") ? "Custom" : country.code)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Search or select a country...")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ZStack {
                    AVTheme.gradient.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.7))
                            
                            TextField("Search countries...", text: $searchText)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Countries List or Custom Input
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if showingCustomInput {
                                    // Custom Country Input
                                    VStack(spacing: 16) {
                                        Text("Enter Country Name")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .padding(.top)
                                        
                                        TextField("Type country name...", text: $customCountryName)
                                            .textFieldStyle(.plain)
                                            .foregroundStyle(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        Text("We'll find it on the map and add it to your list")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                        
                                        HStack(spacing: 12) {
                                            Button {
                                                showingCustomInput = false
                                                customCountryName = ""
                                            } label: {
                                                Text("Cancel")
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 12)
                                                    .background(Color.black.opacity(0.3))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            
                                            Button {
                                                Task {
                                                    if !customCountryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                        isAddingCountry = true
                                                        if let customCountry = await createCustomCountry(name: customCountryName) {
                                                            selectedCountry = customCountry
                                                            showingPicker = false
                                                            showingCustomInput = false
                                                            customCountryName = ""
                                                        }
                                                        isAddingCountry = false
                                                    }
                                                }
                                            } label: {
                                                HStack {
                                                    if isAddingCountry {
                                                        ProgressView()
                                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                            .scaleEffect(0.8)
                                                        Text("Adding...")
                                                    } else {
                                                        Text("Add")
                                                    }
                                                }
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(customCountryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingCountry ? Color.gray.opacity(0.3) : Color.green)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            .disabled(customCountryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingCountry)
                                        }
                                    }
                                    .padding()
                                } else {
                                    // Countries List
                                    ForEach(filteredCountries) { country in
                                        Button {
                                            selectedCountry = country
                                            showingPicker = false
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "globe")
                                                    .font(.title3)
                                                    .foregroundStyle(.white.opacity(0.7))
                                                    .frame(width: 30)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(country.name)
                                                        .font(.body)
                                                        .foregroundStyle(.white)
                                                    Text("\(country.code) • \(country.continent.displayName)")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                }
                                                
                                                Spacer()
                                                
                                                if selectedCountry?.id == country.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.green)
                                                }
                                            }
                                            .padding(12)
                                            .background(Color.black.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                    
                                    // "Others" option at the bottom
                                    Button {
                                        showingCustomInput = true
                                        searchText = ""
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.orange)
                                                .frame(width: 30)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Others (Add Custom Country)")
                                                    .font(.body)
                                                    .foregroundStyle(.white)
                                                Text("Type a country name if not listed")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        .padding(12)
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Select Country")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingPicker = false
                            showingCustomInput = false
                            customCountryName = ""
                            searchText = ""
                        }
                        .foregroundStyle(.white)
                    }
                }
                .onAppear {
                    // Reset custom input when sheet appears
                    showingCustomInput = false
                    customCountryName = ""
                    searchText = ""
                }
            }
            .presentationDetents([.large])
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    TravelMapView()
}
