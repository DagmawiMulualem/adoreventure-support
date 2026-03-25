//
//  IdeasListView.swift
//  AdoreVenture
//

//
//  IdeaDetailView.swift
//  AdoreVenture
//

import SwiftUI
import Foundation
import UIKit

// MARK: - Checklist Models

struct ChecklistItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var category: ChecklistCategory
    var order: Int
    
    enum ChecklistCategory: String, Codable, CaseIterable {
        case preparation = "Preparation"
        case booking = "Booking"
        case logistics = "Logistics"
        case personal = "Personal"
        case safety = "Safety"
        case enjoyment = "Enjoyment"
        
        var icon: String {
            switch self {
            case .preparation: return "checklist"
            case .booking: return "calendar.badge.plus"
            case .logistics: return "car.fill"
            case .personal: return "person.fill"
            case .safety: return "shield.fill"
            case .enjoyment: return "heart.fill"
            }
        }
        
        var color: String {
            switch self {
            case .preparation: return "blue"
            case .booking: return "green"
            case .logistics: return "orange"
            case .personal: return "purple"
            case .safety: return "red"
            case .enjoyment: return "pink"
            }
        }
    }
}

struct IdeaDetailView: View {
    let idea: AVIdea
    var locationContext: String? = nil
    @EnvironmentObject var firebaseManager: FirebaseManager
    @State private var checklistItems: [ChecklistItem] = []
    @State private var lastSavedDate: Date?
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    @State private var showCustomItemDialog = false
    @State private var customItemText = ""
    @Environment(\.openURL) private var openURL
    
    private let autoSaveDelay: TimeInterval = 2.0

    var body: some View {
        ZStack {
            // Background gradient
            AVTheme.gradient.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Hero Header Section
                    heroHeaderSection
                    
                    // Quick Stats Row
                    quickStatsRow
                    
                    // Description Card
                    descriptionCard
                    
                    // Details section
                    detailsSection

                    // Quick actions
                    quickActions

                    // Tags
                    if !idea.tags.isEmpty {
                        tagsSection
                    }

                    // Activity Checklist
                    checklistSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChecklist()
        }
        .sheet(isPresented: $showCustomItemDialog) {
            customItemDialog
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task {
                        await firebaseManager.toggleBookmark(for: idea)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: firebaseManager.isBookmarked(idea) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(firebaseManager.isBookmarked(idea) ? .yellow : .primary)
                        .font(.title2)
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.primary)
                        .font(.title2)
                }
            }
        }
    }

    // MARK: - Sections
    
    @ViewBuilder
    private var heroHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(idea.title)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            
            HStack(spacing: 20) {
                Label(String(format: "%.1f", idea.rating), systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                
                Label(idea.place, systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var quickStatsRow: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "clock.fill",
                title: "Duration",
                value: idea.duration,
                color: .blue
            )
            
            StatCard(
                icon: "dollarsign.circle.fill",
                title: "Price",
                value: idea.priceRange,
                color: .green
            )
            
            if let bestTime = idea.bestTime, !bestTime.isEmpty {
                StatCard(
                    icon: "sun.max.fill",
                    title: "Best Time",
                    value: extractTimeFromBestTime(bestTime),
                    color: .orange
                )
            }
        }
    }
    
    @ViewBuilder
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("About This Activity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            
            Text(idea.blurb)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Tags")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80, maximum: 140), spacing: 10)
            ], spacing: 10) {
                ForEach(idea.tags, id: \.self) { tag in
                    AVTag(text: tag)
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Activity Checklist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Progress indicator
                let completedCount = checklistItems.filter { $0.isCompleted }.count
                let totalCount = checklistItems.count
                if totalCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text("completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Quick checklist templates
            if checklistItems.isEmpty {
                quickChecklistTemplates
            }
            
            // Checklist items
            if !checklistItems.isEmpty {
                VStack(spacing: 12) {
                    ForEach(ChecklistItem.ChecklistCategory.allCases, id: \.self) { category in
                        let categoryItems = checklistItems.filter { $0.category == category }
                        if !categoryItems.isEmpty {
                            checklistCategorySection(category: category, items: categoryItems)
                        }
                    }
                }
                
                // Action buttons
                HStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Add custom item button
                        Button {
                            addCustomChecklistItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AVTheme.accent)
                        }
                        .buttonStyle(.plain)
                        
                        // Reset button
                        Button {
                            resetChecklist()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        
                        // Share button
                        ShareLink(item: createShareableChecklist()) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(AVTheme.accent)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            loadChecklist()
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Contact & Information")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 12) {
                if let address = idea.address, !address.isEmpty {
                    detailRow(icon: "map.fill", text: address)
                }

                if let phone = idea.phone, !phone.isEmpty {
                    Button {
                        if let url = URL(string: "tel://\(digits(from: phone))") { openURL(url) }
                    } label: {
                        detailRow(icon: "phone.fill", text: phone, isLink: true)
                    }
                    .buttonStyle(.plain)
                }

                if let hours = idea.hours, !hours.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .frame(width: 20)
                                .foregroundStyle(AVTheme.accent)
                            Text("Hours")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(hours, id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 28)
                    }
                }

                // Show website button if website exists and is trustworthy
                if let website = idea.website, let url = URL(string: normalizeURL(website)), isTrustworthyWebsite(website) {
                    Button {
                        openURL(url)
                    } label: {
                        detailRow(
                            icon: "globe",
                            text: isGoogleSearchURL(website) ? "Search on Google" : "Visit Website",
                            isLink: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Show reservation button if booking URL exists
                if let booking = idea.bookingURL, let url = URL(string: normalizeURL(booking)) {
                    Button {
                        openURL(url)
                    } label: {
                        detailRow(
                            icon: "ticket.fill",
                            text: isGoogleSearchURL(booking) ? "Find booking info (Google)" : "Book Reservations",
                            isLink: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func detailRow(icon: String, text: String, isLink: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(AVTheme.accent)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isLink ? AVTheme.accent : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(AVTheme.accent)
            }
        }
        .padding(12)
        .background(isLink ? AVTheme.accent.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 12) {
                // Maps: Google Maps search by place + location (avoids wrong pins from guessed addresses)
                Button {
                    if let url = googleMapsSearchURL() {
                        openURL(url)
                    }
                } label: {
                    actionLabel(
                        title: "Open in Maps",
                        subtitle: "Google Maps search for this place",
                        systemImage: "map.fill"
                    )
                }

                // Show "Search on the Web" if no trustworthy website exists
                if !hasTrustworthyWebsite() {
                    Button {
                        let query = webQuery()
                        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
                            openURL(url)
                        }
                    } label: {
                        actionLabel(
                            title: "Search on the Web",
                            subtitle: "Find official site or reservations",
                            systemImage: "safari.fill"
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func actionLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(AVTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: 1)
        )
        }
    
    @ViewBuilder
    private var quickChecklistTemplates: some View {
        VStack(spacing: 12) {
            Text("Quick Start Checklists")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // Smart checklist
                Button {
                    generateChecklistForCategory()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)
                        Text("Smart Checklist")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // Custom checklist
                Button {
                    addCustomChecklistItem()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text("Add Custom")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    /// Raw search text for maps (place + title + user location — not AI street address, often wrong overseas).
    private func mapsSearchRawQuery() -> String {
        [idea.place, idea.title, locationContext]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func googleMapsSearchURL() -> URL? {
        let raw = mapsSearchRawQuery()
        guard !raw.isEmpty else { return nil }
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
    }

    private func webQuery() -> String {
        // Create a more targeted search query to find the official website
        var searchTerms: [String] = []
        
        // Add the place/business name first (most important for finding official site)
        searchTerms.append(idea.place)
        
        // Add the activity title
        searchTerms.append(idea.title)
        
        // Add the location context if available
        if let location = locationContext, !location.isEmpty {
            searchTerms.append(location)
        }
        
        // Add "official website" to prioritize finding the actual website
        searchTerms.append("official website")
        
        // Join all terms and encode for URL
        let base = searchTerms.joined(separator: " ")
        return base.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? base
    }
    
    private func isGoogleSearchURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("google.com/search") || lowercased.contains("google.com/maps")
    }

    /// Check if a website URL is trustworthy
    private func isTrustworthyWebsite(_ website: String) -> Bool {
        let lowercased = website.lowercased()

        // Intentional Google Search / Maps fallbacks (safe when venue URL unknown)
        if isGoogleSearchURL(website) {
            return true
        }
        
        // Trusted domains
        let trustedDomains = [
            ".gov", ".edu", ".org", ".mil", ".museum", ".travel",
            "disney.com", "nps.gov", "si.edu", "metmuseum.org",
            "broadway.com", "ticketmaster.com", "eventbrite.com",
            "opentable.com", "resy.com", "airbnb.com", "booking.com"
        ]
        
        // Check if website contains any trusted domains
        for domain in trustedDomains {
            if lowercased.contains(domain.lowercased()) {
                return true
            }
        }
        
        // Check for suspicious patterns
        let suspiciousPatterns = [
            "example.com", "test.com", "demo.com", "placeholder.com",
            "fake.com", "mock.com", "dummy.com", "sample.com"
        ]
        
        for pattern in suspiciousPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        // If it's a valid URL format and doesn't contain suspicious patterns, consider it trustworthy
        return website.contains(".") && !website.contains(" ")
    }
    
    /// Check if there's a trustworthy website available
    private func hasTrustworthyWebsite() -> Bool {
        if let website = idea.website {
            return isTrustworthyWebsite(website)
        }
        return false
    }

    private func digits(from phone: String) -> String {
        phone.filter("0123456789".contains)
    }

    private func normalizeURL(_ s: String) -> String {
        if s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") {
            return s
        }
        return "https://\(s)"
    }

    private var shareText: String {
        """
        \(idea.title)
        \(idea.blurb)

        Where: \(idea.place)\(idea.address != nil ? " • \(idea.address!)" : "")
        Duration: \(idea.duration) • Price: \(idea.priceRange)
        \(idea.bestTime != nil ? "Best time: \(extractTimeFromBestTime(idea.bestTime!))" : "")
        """
    }
    
    // MARK: - Checklist Methods
    
    private func saveChecklist() async {
        isSaving = true
        // Save to UserDefaults with idea ID as key
        if let data = try? JSONEncoder().encode(checklistItems) {
            UserDefaults.standard.set(data, forKey: "checklist_\(idea.id)")
        }
        lastSavedDate = Date()
        isSaving = false
    }
    
    private func loadChecklist() {
        if let data = UserDefaults.standard.data(forKey: "checklist_\(idea.id)"),
           let items = try? JSONDecoder().decode([ChecklistItem].self, from: data) {
            checklistItems = items
        }
    }
    
    private func generateChecklistForCategory() {
        checklistItems = []
        var order = 0
        
        // Get category from idea tags or use a default
        let category = getCategoryFromTags()
        
        switch category {
        case .date:
            checklistItems = generateDateChecklist(order: &order)
        case .birthday:
            checklistItems = generateBirthdayChecklist(order: &order)
        case .travel:
            checklistItems = generateTravelChecklist(order: &order)
        case .local:
            checklistItems = generateLocalChecklist(order: &order)
        case .special:
            checklistItems = generateSpecialChecklist(order: &order)
        case .group:
            checklistItems = generateGroupChecklist(order: &order)
        }
        
        Task { await saveChecklist() }
    }
    

    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Checklist Generation Methods
    
    private func getCategoryFromTags() -> AVCategory {
        let tags = idea.tags.map { $0.lowercased() }
        
        if tags.contains("date") || tags.contains("romantic") || tags.contains("couple") {
            return .date
        } else if tags.contains("birthday") || tags.contains("celebration") {
            return .birthday
        } else if tags.contains("travel") || tags.contains("tourist") || tags.contains("sightseeing") {
            return .travel
        } else if tags.contains("group") || tags.contains("friends") || tags.contains("family") {
            return .group
        } else if tags.contains("special") || tags.contains("holiday") || tags.contains("seasonal") {
            return .special
        } else {
            return .local
        }
    }
    
    private func generateDateChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Research the activity", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check reviews and ratings", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Make reservation", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        items.append(ChecklistItem(title: "Confirm date and time", isCompleted: false, category: .booking, order: order))
        order += 1
        
        // Logistics
        items.append(ChecklistItem(title: "Plan transportation", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check parking availability", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Plan outfit", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Charge phone", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Bring payment method", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Safety
        items.append(ChecklistItem(title: "Share location with friend", isCompleted: false, category: .safety, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan conversation topics", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Think of backup plan", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateBirthdayChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Plan guest list", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Send invitations", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Book venue/activity", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        items.append(ChecklistItem(title: "Confirm group size", isCompleted: false, category: .booking, order: order))
        order += 1
        
        // Logistics
        items.append(ChecklistItem(title: "Plan transportation for group", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Arrange decorations", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Plan birthday outfit", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Prepare camera/phone", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan birthday activities", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Prepare thank you notes", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateTravelChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Research destination", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check travel requirements", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        items.append(ChecklistItem(title: "Book transportation", isCompleted: false, category: .booking, order: order))
        order += 1
        items.append(ChecklistItem(title: "Book accommodation", isCompleted: false, category: .booking, order: order))
        order += 1
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Book activity", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        
        // Logistics
        items.append(ChecklistItem(title: "Pack essentials", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Plan itinerary", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Safety
        items.append(ChecklistItem(title: "Check travel insurance", isCompleted: false, category: .safety, order: order))
        order += 1
        items.append(ChecklistItem(title: "Share travel plans", isCompleted: false, category: .safety, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Download offline maps", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Research local customs", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateLocalChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Check opening hours", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Read recent reviews", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Make reservation", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        
        // Logistics
        items.append(ChecklistItem(title: "Plan route", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check parking", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Dress appropriately", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Bring essentials", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan backup activity", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateSpecialChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Check event details", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Plan special outfit", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Get tickets", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        
        // Logistics
        items.append(ChecklistItem(title: "Plan arrival time", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Arrange transportation", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Prepare for photos", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan special moments", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateGroupChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Confirm group size", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Create group chat", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Book group reservation", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        items.append(ChecklistItem(title: "Check group discounts", isCompleted: false, category: .booking, order: order))
        order += 1
        
        // Logistics
        items.append(ChecklistItem(title: "Plan meeting point", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Coordinate arrival times", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Plan group activities", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan group photos", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Split costs fairly", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    // MARK: - Checklist UI Methods
    
    @ViewBuilder
    private func checklistCategorySection(category: ChecklistItem.ChecklistCategory, items: [ChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(Color(category.color))
                    .font(.headline)
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            ForEach(items.sorted(by: { $0.order < $1.order })) { item in
                checklistItemRow(item: item)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func checklistItemRow(item: ChecklistItem) -> some View {
        HStack {
            Button {
                toggleChecklistItem(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .font(.subheadline)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private func toggleChecklistItem(_ item: ChecklistItem) {
        if let index = checklistItems.firstIndex(where: { $0.id == item.id }) {
            checklistItems[index].isCompleted.toggle()
            Task { await saveChecklist() }
        }
    }
    
    private func addCustomChecklistItem() {
        customItemText = ""
        showCustomItemDialog = true
    }
    
    private func addCustomItemFromDialog() {
        guard !customItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newItem = ChecklistItem(
            title: customItemText.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false,
            category: .personal,
            order: checklistItems.count
        )
        checklistItems.append(newItem)
        showCustomItemDialog = false
        customItemText = ""
        Task { await saveChecklist() }
    }
    
    private func resetChecklist() {
        for index in checklistItems.indices {
            checklistItems[index].isCompleted = false
        }
        Task { await saveChecklist() }
    }
    
    private func createShareableChecklist() -> String {
        var shareableText = "📋 **CHECKLIST FOR \(idea.title.uppercased())**\n\n"
        
        for category in ChecklistItem.ChecklistCategory.allCases {
            let categoryItems = checklistItems.filter { $0.category == category }
            if !categoryItems.isEmpty {
                shareableText += "**\(category.rawValue):**\n"
                for item in categoryItems.sorted(by: { $0.order < $1.order }) {
                    let status = item.isCompleted ? "✅" : "□"
                    shareableText += "\(status) \(item.title)\n"
                }
                shareableText += "\n"
            }
        }
        
        shareableText += "📍 \(idea.place)"
        if let locationContext = locationContext {
            shareableText += " • \(locationContext)"
        }
        
        return shareableText
    }
    
    // MARK: - Custom Item Dialog
    
    @ViewBuilder
    private var customItemDialog: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Custom Checklist Item")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("Type your custom task or plan for this activity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    TextField("Enter your custom task...", text: $customItemText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .onSubmit {
                            addCustomItemFromDialog()
                        }
                    
                    HStack {
                        Text("\(customItemText.count)/100")
                            .font(.caption)
                            .foregroundStyle(customItemText.count > 80 ? .orange : .secondary)
                        
                        Spacer()
                        
                        if !customItemText.isEmpty {
                            Button("Clear") {
                                customItemText = ""
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                }
                
                Spacer()
                
                // Example suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Suggestions:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Check weather forecast")
                        Text("• Bring camera/phone")
                        Text("• Research parking options")
                        Text("• Plan backup activity")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .navigationTitle("Custom Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomItemDialog = false
                        customItemText = ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCustomItemFromDialog()
                    }
                    .disabled(customItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}



// MARK: - View state cache (survives parent re-renders that recreate IdeasListView)
private enum IdeasListViewModelCache {
    private static var store: [String: (items: [AVIdea], allShownIdeaIds: Set<String>)] = [:]
    private static let lock = NSLock()
    
    static func key(location: String, category: AVCategory, preferences: SearchPreferences?) -> String {
        let pref = preferences?.cacheKeySuffix ?? "no_prefs"
        return "\(location)|\(category.rawValue)|\(pref)"
    }
    
    static func restore(key: String) -> (items: [AVIdea], allShownIdeaIds: Set<String>)? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }
    
    static func save(key: String, items: [AVIdea], allShownIdeaIds: Set<String>) {
        lock.lock()
        store[key] = (items, allShownIdeaIds)
        lock.unlock()
        IdeasListPersistence.save(key: key, items: items, allShownIdeaIds: allShownIdeaIds)
    }
}

// MARK: - Persist list across app close so same ideas show when user comes back
private enum IdeasListPersistence {
    private static let prefix = "IdeasList_"
    
    static func key(location: String, category: AVCategory, preferences: SearchPreferences?) -> String {
        let pref = preferences?.cacheKeySuffix ?? "no_prefs"
        return "\(location)|\(category.rawValue)|\(pref)"
    }
    
    static func restore(key: String) -> (items: [AVIdea], allShownIdeaIds: Set<String>)? {
        let k = prefix + key
        guard let data = UserDefaults.standard.data(forKey: k),
              let decoded = try? JSONDecoder().decode(IdeasListPersistencePayload.self, from: data) else { return nil }
        let items = decoded.items.map { $0.rehydratedThroughInit() }
        return (items, Set(decoded.allShownIdeaIds))
    }
    
    static func save(key: String, items: [AVIdea], allShownIdeaIds: Set<String>) {
        let payload = IdeasListPersistencePayload(items: items, allShownIdeaIds: Array(allShownIdeaIds))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: prefix + key)
    }
}

private struct IdeasListPersistencePayload: Codable {
    let items: [AVIdea]
    let allShownIdeaIds: [String]
}

struct IdeasListView: View {
    let location: String
    let category: AVCategory
    let ideas: [AVIdea]
    let preferences: SearchPreferences?
    var autoFetch: Bool = false

    @State private var items: [AVIdea] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var hasFetchedOnce = false
    @State private var showingSubscriptionPrompt = false
    @State private var allShownIdeaIds: Set<String> = []
    @State private var allShownIdeaTitles: Set<String> = []
    @State private var shownIdeaIds: Set<String> = []
    @State private var loadingMessageIndex = 0
    @State private var loadingTimer: Timer?
    @State private var showWordScrambleGame = false
    @State private var isColdLocation = false
    @State private var showTimeoutAlert = false
    @State private var bonusCreditsGiven = false
    @State private var streamingTask: Task<Void, Never>?
    /// Tracks which search we last fetched for; when location/category changes we clear and re-fetch
    @State private var lastFetchedSearchKey: String?
    /// Stale-while-revalidate: show cached cards, then `forceRefresh` streaming (one automatic pass per search key per session).
    @State private var isBackgroundRefreshing = false
    @State private var staleWhileRevalidateCompletedKey: String?

    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var ideaCacheService = IdeaCacheService.shared

    
    // Interactive loading messages
    private var loadingMessages: [String] {
        if isColdLocation {
            // Cold location: no cache yet, make it feel special and intentional
            return [
                "🌍 You're the first exploring this location…",
                "✨ Creating unique ideas just for this place…",
                "🎒 Almost ready… crafting your custom adventures…"
            ]
        } else {
            // Warm / cached locations: general fast-feeling messages
            return [
                "🤖 AI is brainstorming ideas...",
                "🔍 Finding the best \(category.rawValue) activities...",
                "⭐ Discovering hidden gems in \(location)...",
                "🎯 Curating recommendations...",
                "✨ Almost there! Finalizing your list...",
                "🚀 Preparing your perfect experience...",
                "💫 Discovering unique spots...",
                "🎪 Finding exciting activities...",
                "🌟 Handpicking the best experiences...",
                "🎨 Crafting your adventure..."
            ]
        }
    }
    
    private var currentLoadingMessage: String {
        let baseMessage = loadingMessages[loadingMessageIndex % loadingMessages.count]
        return baseMessage.replacingOccurrences(of: "\(AVCategory.local.rawValue)", with: category.rawValue)
    }

    private var listCacheKey: String {
        IdeasListViewModelCache.key(location: location, category: category, preferences: preferences)
    }

    private var budgetHint: String? { preferences?.budgetHint }
    private var timeHint: String? { nil }
    private var indoorOutdoorHint: String? { preferences?.indoorOutdoorHint(for: category) }

    init(location: String, category: AVCategory, ideas: [AVIdea], preferences: SearchPreferences? = nil, autoFetch: Bool = false) {
        self.location = location
        self.category = category
        self.ideas = ideas
        self.preferences = preferences
        self.autoFetch = autoFetch
        let cacheKey = IdeasListViewModelCache.key(location: location, category: category, preferences: preferences)
        if ideas.isEmpty {
            if let cached = IdeasListViewModelCache.restore(key: cacheKey) {
                _items = State(initialValue: cached.items)
                _allShownIdeaIds = State(initialValue: cached.allShownIdeaIds)
                _allShownIdeaTitles = State(initialValue: Set(cached.items.map(\.title)))
                _shownIdeaIds = State(initialValue: cached.allShownIdeaIds)
                print("📱 LIST: init \(location) | \(category.rawValue) | RESTORED from memory items.count=\(cached.items.count)")
            } else if let persisted = IdeasListPersistence.restore(key: cacheKey), !persisted.items.isEmpty {
                _items = State(initialValue: persisted.items)
                _allShownIdeaIds = State(initialValue: persisted.allShownIdeaIds)
                _allShownIdeaTitles = State(initialValue: Set(persisted.items.map(\.title)))
                _shownIdeaIds = State(initialValue: persisted.allShownIdeaIds)
                IdeasListViewModelCache.save(key: cacheKey, items: persisted.items, allShownIdeaIds: persisted.allShownIdeaIds)
                print("📱 LIST: init \(location) | \(category.rawValue) | RESTORED from disk items.count=\(persisted.items.count) (same ideas after app reopen)")
            } else {
                _items = State(initialValue: [])
                _allShownIdeaIds = State(initialValue: [])
                _allShownIdeaTitles = State(initialValue: [])
                _shownIdeaIds = State(initialValue: [])
                print("📱 LIST: init \(location) | \(category.rawValue) | empty | autoFetch=\(autoFetch)")
            }
        } else {
            _items = State(initialValue: ideas)
            _allShownIdeaIds = State(initialValue: [])
            _allShownIdeaTitles = State(initialValue: [])
            _shownIdeaIds = State(initialValue: [])
            print("📱 LIST: init \(location) | \(category.rawValue) | initial ideas.count=\(ideas.count) | autoFetch=\(autoFetch)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Perfect \(category.rawValue.capitalized) Ideas in \(location)")
                            .font(.system(size: 28, weight: .bold))
                        Text("Handpicked suggestions tailored to your interests")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                                            HStack(spacing: 8) {
                            Button {
                                Task { await fetchMoreIdeas() }
                            } label: {
                                HStack(spacing: 6) { 
                                    Text(isLoading ? "Loading..." : "More Ideas")
                                    Text("✨") 
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(AVTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .disabled(isLoading)
                            


                        }
                }
                
                // Search limit indicator
                HStack {
                    Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "magnifyingglass")
                        .foregroundStyle(subscriptionManager.isSubscribed ? .yellow : .secondary)
                    Text(subscriptionManager.searchLimitMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)

                if isBackgroundRefreshing && !items.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Updating with fresh ideas…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let errorMsg {
                    CompactErrorDisplayView(
                        error: NSError(domain: "IdeasListView", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg]),
                        retryAction: {
                            Task { await fetchFromAI() }
                        }
                    )
                    .padding(.top, 8)
                }

                if isLoading && items.isEmpty {
                    VStack(spacing: 16) {
                        // Animated loading indicator
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .foregroundStyle(AVTheme.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generating Ideas")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text(currentLoadingMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .animation(.easeInOut(duration: 0.5), value: loadingMessageIndex)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.clear)
                        
                        // Status message - shows after 10-15 seconds of loading
                        if loadingMessageIndex > 4 { // Show after 5th message (about 10-15 seconds)
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(.blue)
                                    Text("Taking longer than expected?")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                                
                                Text("While you wait, try our Travel Trivia game!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Game appears in \(max(0, 8 - loadingMessageIndex)) more messages...")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .transition(.opacity.combined(with: .scale))
                        }
                        

                        
                        // Travel Trivia Game - shows after 8th message (about 15-20 seconds)
                        if showWordScrambleGame {
                            TravelTriviaGame()
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale).combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .scale).combined(with: .move(edge: .top))
                                ))
                                .animation(.easeInOut(duration: 0.6), value: showWordScrambleGame)
                                .onAppear {
                                    // Add a subtle floating animation
                                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                        // This will be handled by the game component
                                    }
                                }
                        }
                        
                        // Fun fact or tip
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text("Did you know?")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                            
                            Text("Our AI analyzes thousands of reviews and local insights to find the perfect activities for you!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.vertical, 16)
                }
                



                if items.isEmpty && !isLoading {
                    // Friendly empty state
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundStyle(AVTheme.accent)
                        
                        Text("Ready to Discover?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Tap 'More Ideas' to generate amazing \(category.rawValue.lowercased()) suggestions for \(location)!")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            Task { await fetchFromAI() }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Generate Ideas")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AVTheme.accent, in: Capsule())
                        }
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(items) { idea in
                            IdeaCard(idea: idea, locationContext: location)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: listCacheKey) {
            let key = listCacheKey
            print("📱 LIST: .task(id) ran | key=\(key) lastKey=\(lastFetchedSearchKey ?? "nil") items.count=\(items.count)")
            // When search context changes (new location/category), clear old list and fetch for new search
            if let last = lastFetchedSearchKey, last != key {
                print("📱 LIST: search changed \(last) → \(key), clearing and re-fetching")
                await MainActor.run {
                    streamingTask?.cancel()
                    items.removeAll()
                    allShownIdeaIds.removeAll()
                    allShownIdeaTitles.removeAll()
                    shownIdeaIds.removeAll()
                    staleWhileRevalidateCompletedKey = nil
                }
            }
            lastFetchedSearchKey = key
            guard autoFetch else {
                if !items.isEmpty { hasFetchedOnce = true }
                return
            }
            hasFetchedOnce = true
            if items.isEmpty {
                await fetchFromAI()
            } else if staleWhileRevalidateCompletedKey != key {
                print("📱 LIST: stale-while-revalidate — showing \(items.count) cached ideas, refreshing in background")
                await fetchFromAI(staleWhileRevalidate: true)
                await MainActor.run {
                    staleWhileRevalidateCompletedKey = key
                }
            }
        }
        .onAppear {
            print("📱 LIST: onAppear \(location) | \(category.rawValue) | items.count=\(items.count) allShownIdeaIds.count=\(allShownIdeaIds.count)")
        }
        .sheet(isPresented: $showingSubscriptionPrompt) {
            SubscriptionPromptView()
                .environmentObject(subscriptionManager)
        }
        .alert("🎁 50 Bonus Credits!", isPresented: $showTimeoutAlert) {
            Button("✨ Try Again") {
                bonusCreditsGiven = false
                Task { await fetchFromAI() }
            }
            Button("Thanks!", role: .cancel) {
                bonusCreditsGiven = false
            }
        } message: {
            Text("Our AI got a little overwhelmed with your awesome request! Here's 50 credits on us while we catch our breath. Ready to go again?")
        }
        .onDisappear {
            stopLoadingAnimation()
            showWordScrambleGame = false
        }
    }

    private func fetchFromAI(staleWhileRevalidate: Bool = false) async {
        guard !isLoading, !isBackgroundRefreshing else {
            print("📱 LIST: fetchFromAI skipped - another fetch is already in progress")
            return
        }
        let startedAt = Date()
        let searchType = "Search"

        let cachedSnapshot = await ideaCacheService.getCachedIdeasOnly(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoorHint
        )

        if staleWhileRevalidate {
            await MainActor.run {
                streamingTask?.cancel()
                if items.isEmpty, let snap = cachedSnapshot, !snap.isEmpty {
                    items = snap
                    allShownIdeaIds = Set(snap.map(\.id))
                    allShownIdeaTitles = Set(snap.map(\.title))
                    shownIdeaIds = Set(snap.map(\.id))
                    IdeasListViewModelCache.save(
                        key: listCacheKey,
                        items: items,
                        allShownIdeaIds: allShownIdeaIds
                    )
                }
                isBackgroundRefreshing = true
                errorMsg = nil
                isColdLocation = false
            }
        } else {
            await MainActor.run {
                streamingTask?.cancel()
                items.removeAll()
                allShownIdeaIds.removeAll()
                allShownIdeaTitles.removeAll()
                shownIdeaIds.removeAll()
            }
            isColdLocation = (cachedSnapshot == nil)
            isLoading = true
            errorMsg = nil
            startLoadingAnimation()
        }

        let startCounts = await MainActor.run { (items.count, allShownIdeaIds.count) }
        print("📱 LIST: fetchFromAI START \(location) | \(category.rawValue) | staleWhileRevalidate=\(staleWhileRevalidate) | items.count=\(startCounts.0) allShownIdeaIds.count=\(startCounts.1)")

        print("📱 UI: Using caching system…")

        final class FreshIdeaState: @unchecked Sendable {
            var isFirst = true
        }
        let freshIdeaState = FreshIdeaState()
        let onIdea: (AVIdea) -> Void = { idea in
            if staleWhileRevalidate, freshIdeaState.isFirst {
                freshIdeaState.isFirst = false
                hideTravelTriviaForStreamingResults()
                items.removeAll()
                shownIdeaIds.removeAll()
                allShownIdeaIds.removeAll()
                allShownIdeaTitles.removeAll()
            }
            if items.isEmpty {
                hideTravelTriviaForStreamingResults()
            }
            allShownIdeaIds.insert(idea.id)
            allShownIdeaTitles.insert(idea.title)
            shownIdeaIds.insert(idea.id)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                items.append(idea)
            }
            IdeasListViewModelCache.save(
                key: listCacheKey,
                items: items,
                allShownIdeaIds: allShownIdeaIds
            )
        }
        
        do {
            // Try true streaming first (getSingleIdea); if NOT FOUND / not deployed, fall back to batch
            let result: [AVIdea]
            do {
                result = try await ideaCacheService.getIdeasStreaming(
                    location: location,
                    category: category,
                    budgetHint: budgetHint,
                    timeHint: timeHint,
                    indoorOutdoor: indoorOutdoorHint,
                    forceRefresh: staleWhileRevalidate,
                    onBatchFallbackReset: {
                        // Batch fallback re-delivers 3 ideas; drop partial single-idea cards first (avoids 2 + 3 = 5 on screen).
                        await MainActor.run {
                            items.removeAll()
                            allShownIdeaIds.removeAll()
                            allShownIdeaTitles.removeAll()
                            shownIdeaIds.removeAll()
                        }
                    },
                    onIdea: { idea in await MainActor.run { onIdea(idea) } }
                )
                print("📱 LIST: fetchFromAI streaming done | result.count=\(result.count) | items.count=\(items.count)")
            } catch {
                if error is CancellationError {
                    throw error
                }
                // Fall back to batch when streaming is unavailable (not found), or on timeout/internal so user still gets ideas
                let errDesc = error.localizedDescription.lowercased()
                let isNotFound = errDesc.contains("not found") ||
                    errDesc.contains("unavailable") ||
                    (errDesc.contains("function") && errDesc.contains("not")) ||
                    (error as NSError).code == 404
                let isTimeoutOrInternal = errDesc.contains("timeout") ||
                    errDesc.contains("timed out") ||
                    errDesc.contains("internal") ||
                    errDesc.contains("deadline-exceeded") ||
                    errDesc.contains("result accumulator") ||
                    (error as NSError).code == 4 // Firebase deadline-exceeded
                if isNotFound || isTimeoutOrInternal {
                    let reason = isTimeoutOrInternal ? "timeout/internal" : "not found"
                    print("📱 UI: Streaming unavailable or failed (\(reason)), falling back to batch getIdeas")
                    let batch = try await ideaCacheService.getIdeas(
                        location: location,
                        category: category,
                        budgetHint: budgetHint,
                        timeHint: timeHint,
                        indoorOutdoor: indoorOutdoorHint,
                        forceRefresh: staleWhileRevalidate
                    )
                    result = batch
                    for idea in batch {
                        await MainActor.run { onIdea(idea) }
                        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s between cards
                    }
                } else {
                    throw error
                }
            }
            if result.isEmpty {
                print("📱 UI: No ideas returned")
            }
        } catch {
            if error is CancellationError {
                print("📱 LIST: fetchFromAI cancelled — skipping error UI")
                await MainActor.run {
                    isLoading = false
                    isBackgroundRefreshing = false
                    stopLoadingAnimation()
                }
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "cancelled")
                return
            }
            print("📱 UI: ❌ Error fetching ideas: \(error.localizedDescription)")
            
            let nsError = error as NSError
            let isTimeout = nsError.domain == NSURLErrorDomain && nsError.code == -1001 ||
                           nsError.code == 4 ||
                           error.localizedDescription.lowercased().contains("timeout") ||
                           error.localizedDescription.lowercased().contains("timed out")
            
            if isTimeout {
                // Timeout error - refund credits and show friendly message
                print("📱 UI: ⏱️ Timeout detected - refunding credits")
                subscriptionManager.giveBonusCreditsForIssue()
                bonusCreditsGiven = true
                showTimeoutAlert = true
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "timeout")
            } else if nsError.code == -3 {
                // Subscription limit reached
                showingSubscriptionPrompt = true
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "blocked_subscription")
            } else {
                // Other errors - try cached ideas only (no generic fallback)
                print("📱 UI: Error occurred, checking for cached ideas...")
                let cachedIdeas = await getCachedIdeas()
                if !cachedIdeas.isEmpty {
                    print("📱 UI: Found \(cachedIdeas.count) cached ideas")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        items = cachedIdeas
                    }
                    let ids = Set(cachedIdeas.map { $0.id })
                    IdeasListViewModelCache.save(
                        key: listCacheKey,
                        items: cachedIdeas,
                        allShownIdeaIds: ids
                    )
                }
                // If no cached ideas, just leave items empty - user can retry
                let outcome = cachedIdeas.isEmpty ? "failed_no_cache" : "failed_used_cache"
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: outcome)
            }
        }

        let endCount = await MainActor.run { () -> Int in
            isLoading = false
            isBackgroundRefreshing = false
            stopLoadingAnimation()
            return items.count
        }
        print("📱 LIST: fetchFromAI END | items.count=\(endCount)")
        if endCount > 0 {
            logSearchDuration(type: searchType, startedAt: startedAt, outcome: "success_ideas=\(endCount)")
        }
    }
    
    // MARK: - Fallback Ideas
    
    private func generateFallbackIdeas() -> [AVIdea] {
        let fallbackIdeas: [AVIdea]
        
        switch category {
        case .date:
            fallbackIdeas = [
                AVIdea(title: "Romantic Dinner", blurb: "Enjoy a candlelit dinner at a local restaurant", rating: 4.5, place: location, duration: "2-3 hours", priceRange: "$$", tags: ["romantic", "dinner", "date"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Evening", hours: nil),
                AVIdea(title: "Sunset Walk", blurb: "Take a peaceful walk during golden hour", rating: 4.2, place: location, duration: "1 hour", priceRange: "Free", tags: ["romantic", "outdoor", "free"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Sunset", hours: nil),
                AVIdea(title: "Coffee Date", blurb: "Visit a cozy local coffee shop", rating: 4.0, place: location, duration: "1-2 hours", priceRange: "$", tags: ["casual", "coffee", "indoor"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Anytime", hours: nil)
            ]
        case .birthday:
            fallbackIdeas = [
                AVIdea(title: "Birthday Party", blurb: "Celebrate with friends and family", rating: 4.7, place: location, duration: "3-4 hours", priceRange: "$$$", tags: ["celebration", "party", "friends"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Evening", hours: nil),
                AVIdea(title: "Birthday Dinner", blurb: "Special dinner at a nice restaurant", rating: 4.4, place: location, duration: "2-3 hours", priceRange: "$$", tags: ["celebration", "dinner", "special"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Evening", hours: nil)
            ]
        case .travel:
            fallbackIdeas = [
                AVIdea(title: "Local Museum", blurb: "Explore the local history and culture", rating: 4.3, place: location, duration: "2-3 hours", priceRange: "$", tags: ["culture", "history", "indoor"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Daytime", hours: nil),
                AVIdea(title: "City Tour", blurb: "Take a guided tour of the city", rating: 4.5, place: location, duration: "3-4 hours", priceRange: "$$", tags: ["sightseeing", "tour", "outdoor"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Daytime", hours: nil)
            ]
        case .local:
            fallbackIdeas = [
                AVIdea(title: "Local Park", blurb: "Enjoy nature in a beautiful local park", rating: 4.1, place: location, duration: "1-2 hours", priceRange: "Free", tags: ["outdoor", "nature", "free"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Daytime", hours: nil),
                AVIdea(title: "Local Market", blurb: "Browse local vendors and crafts", rating: 4.0, place: location, duration: "1-2 hours", priceRange: "$", tags: ["shopping", "local", "outdoor"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Daytime", hours: nil)
            ]
        case .special:
            fallbackIdeas = [
                AVIdea(title: "Special Event", blurb: "Attend a local special event or festival", rating: 4.6, place: location, duration: "2-4 hours", priceRange: "$$", tags: ["event", "festival", "special"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Evening", hours: nil)
            ]
        case .group:
            fallbackIdeas = [
                AVIdea(title: "Group Activity", blurb: "Fun activity perfect for groups", rating: 4.4, place: location, duration: "2-3 hours", priceRange: "$$", tags: ["group", "fun", "social"], address: nil, phone: nil, website: nil, bookingURL: nil, bestTime: "Daytime", hours: nil)
            ]
        }
        
        return fallbackIdeas
    }
    
    // MARK: - Cached Ideas Helper
    
    private func getCachedIdeas() async -> [AVIdea] {
        // Pure cache lookup: never trigger a new AI call here
        if let cached = await ideaCacheService.getCachedIdeasOnly(
            location: location,
            category: category,
            budgetHint: budgetHint,
            timeHint: timeHint,
            indoorOutdoor: indoorOutdoorHint
        ) {
            return cached
        }
        print("📱 UI: No cached ideas available for this key (skipping AI retry)")
        return []
    }
    
    private func fetchMoreIdeas() async {
        guard !isLoading else {
            print("📱 LIST: fetchMoreIdeas skipped - another fetch is already in progress")
            return
        }
        let startedAt = Date()
        let searchType = "More Ideas"
        /// Avoid double metrics when catch logs failure then fall-through logged "success" with restored items.
        var searchMetricLogged = false
        let previousItems = items
        let previousShownIdeaIds = shownIdeaIds
        print("📱 LIST: fetchMoreIdeas START \(location) | \(category.rawValue) | items.count=\(items.count) allShownIdeaIds.count=\(allShownIdeaIds.count)")
        
        // Clear current list before streaming so we don't mix old + new
        await MainActor.run {
            streamingTask?.cancel()
            items.removeAll()
            shownIdeaIds.removeAll()
        }

        isLoading = true
        errorMsg = nil
        startLoadingAnimation()
        
        print("📱 UI: Using streaming system to get more ideas...")
        
        // Streaming callback: append each idea as it arrives
        var streamedBatch: [AVIdea] = []
        var streamedIds = Set<String>()
        /// Single-idea stream cards before batch fallback — must be removed from `allShown*` when fallback resets UI.
        var partialIdeasBeforeBatchFallback: [AVIdea] = []
        let onIdea: (AVIdea) -> Void = { idea in
            // Track this stream payload even if it was shown before, so we can top up to 3 consistently.
            if streamedIds.insert(idea.id).inserted {
                streamedBatch.append(idea)
            }

            // Skip if we've already shown this idea before
            guard !allShownIdeaIds.contains(idea.id) else { return }
            if items.isEmpty {
                hideTravelTriviaForStreamingResults()
            }
            allShownIdeaIds.insert(idea.id)
            allShownIdeaTitles.insert(idea.title)
            shownIdeaIds.insert(idea.id)
            partialIdeasBeforeBatchFallback.append(idea)

            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                items.append(idea)
            }
            IdeasListViewModelCache.save(
                key: listCacheKey,
                items: items,
                allShownIdeaIds: allShownIdeaIds
            )
        }
        
        do {
            // Always try true streaming first for "More Ideas"
            _ = try await ideaCacheService.getIdeasStreaming(
                location: location,
                category: category,
                budgetHint: budgetHint,
                timeHint: timeHint,
                indoorOutdoor: indoorOutdoorHint,
                forceRefresh: true,
                onBatchFallbackReset: {
                    await MainActor.run {
                        items.removeAll()
                        shownIdeaIds.removeAll()
                        for idea in partialIdeasBeforeBatchFallback {
                            allShownIdeaIds.remove(idea.id)
                            allShownIdeaTitles.remove(idea.title)
                        }
                        partialIdeasBeforeBatchFallback.removeAll()
                    }
                },
                onIdea: { idea in await MainActor.run { onIdea(idea) } }
            )

            // Consistency guard: if dedupe caused fewer than 3 visible cards, top up from this same stream batch.
            // This avoids 1-2 card outcomes while still preferring fresh (not previously shown) ideas.
            if items.count < 3 {
                let missing = 3 - items.count
                let currentIds = Set(items.map(\.id))
                let fillers = streamedBatch.filter { !currentIds.contains($0.id) }
                for idea in fillers.prefix(missing) {
                    shownIdeaIds.insert(idea.id)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        items.append(idea)
                    }
                    IdeasListViewModelCache.save(
                        key: listCacheKey,
                        items: items,
                        allShownIdeaIds: allShownIdeaIds
                    )
                }
                if items.count < 3 {
                    print("📱 LIST: fetchMoreIdeas top-up exhausted | items.count=\(items.count) streamedBatch.count=\(streamedBatch.count)")
                }
            }
        } catch {
            print("📱 LIST: fetchMoreIdeas ERROR \(error.localizedDescription)")
            
            if error is CancellationError {
                print("📱 LIST: fetchMoreIdeas cancelled — restoring prior list if needed")
                if items.isEmpty {
                    items = previousItems
                    shownIdeaIds = previousShownIdeaIds
                }
                isLoading = false
                stopLoadingAnimation()
                searchMetricLogged = true
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "cancelled")
                return
            }
            
            // Check if this is "already in progress" error - if so, just wait, don't clear items
            if error.localizedDescription.contains("already in progress") {
                print("📱 UI: ⏳ Another fetch in progress - waiting for it to complete")
                if items.isEmpty {
                    items = previousItems
                    shownIdeaIds = previousShownIdeaIds
                }
                isLoading = false
                stopLoadingAnimation()
                searchMetricLogged = true
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "blocked_in_progress")
                return
            }
            
            let nsError = error as NSError
            let isTimeout = nsError.domain == NSURLErrorDomain && nsError.code == -1001 ||
                           nsError.code == 4 ||
                           error.localizedDescription.lowercased().contains("timeout") ||
                           error.localizedDescription.lowercased().contains("timed out")
            
            if isTimeout {
                // Timeout error - refund credits and show friendly message
                print("📱 UI: ⏱️ Timeout detected - refunding credits")
                subscriptionManager.giveBonusCreditsForIssue()
                bonusCreditsGiven = true
                showTimeoutAlert = true
                if items.isEmpty {
                    items = previousItems
                    shownIdeaIds = previousShownIdeaIds
                }
                searchMetricLogged = true
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "timeout")
            } else if nsError.code == -3 {
                // Subscription limit reached
                showingSubscriptionPrompt = true
                if items.isEmpty {
                    items = previousItems
                    shownIdeaIds = previousShownIdeaIds
                }
                searchMetricLogged = true
                logSearchDuration(type: searchType, startedAt: startedAt, outcome: "blocked_subscription")
            } else {
                // Other errors (e.g. INTERNAL) - try cached ideas; if none, show retry message
                print("📱 UI: Error occurred, checking for cached ideas...")
                let cachedIdeas = await getCachedIdeas()
                if !cachedIdeas.isEmpty {
                    print("📱 UI: Found \(cachedIdeas.count) cached ideas")
                    withAnimation(.easeInOut) {
                        items = cachedIdeas
                    }
                    let ids = Set(cachedIdeas.map { $0.id })
                    IdeasListViewModelCache.save(
                        key: listCacheKey,
                        items: cachedIdeas,
                        allShownIdeaIds: ids
                    )
                    errorMsg = nil
                    searchMetricLogged = true
                    logSearchDuration(type: searchType, startedAt: startedAt, outcome: "failed_used_cache")
                } else {
                    // Keep current items; ask user to retry (don't clear list)
                    if items.isEmpty {
                        items = previousItems
                        shownIdeaIds = previousShownIdeaIds
                    }
                    errorMsg = "Server busy. Tap More Ideas again to retry."
                    searchMetricLogged = true
                    logSearchDuration(type: searchType, startedAt: startedAt, outcome: "failed_no_cache")
                }
            }
        }
        isLoading = false
        stopLoadingAnimation()
        print("📱 LIST: fetchMoreIdeas END | items.count=\(items.count)")
        if !searchMetricLogged, !items.isEmpty {
            logSearchDuration(type: searchType, startedAt: startedAt, outcome: "success_ideas=\(items.count)")
        }
    }
    

    

    // MARK: - Loading Animation Functions

    /// Stops the Travel Trivia countdown/timer and hides the mini-game as soon as real ideas start appearing.
    private func hideTravelTriviaForStreamingResults() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingMessageIndex = 0
        showWordScrambleGame = false
    }
    
    private func startLoadingAnimation() {
        loadingMessageIndex = 0
        showWordScrambleGame = false
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                loadingMessageIndex += 1
                
                // Show word scramble game after 8th message (about 15-20 seconds)
                if loadingMessageIndex == 8 {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showWordScrambleGame = true
                    }
                }
            }
        }
    }
    
    private func stopLoadingAnimation() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingMessageIndex = 0
        showWordScrambleGame = false
    }

    private func logSearchDuration(type: String, startedAt: Date, outcome: String) {
        let elapsed = Date().timeIntervalSince(startedAt)
        let elapsedText = String(format: "%.2f", elapsed)
        print("⏱️ SEARCH METRIC: \(type) | \(location) | \(category.rawValue) | outcome=\(outcome) | duration=\(elapsedText)s")
    }


}



struct IdeaCard: View {
    let idea: AVIdea
    var locationContext: String? = nil   // ← pass the city (e.g., "Washington DC") if you have it
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
                    Image(systemName: firebaseManager.isBookmarked(idea) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(firebaseManager.isBookmarked(idea) ? AVTheme.accent : .secondary)
                }
                .buttonStyle(.plain)
            }

            Text(idea.title)
                .font(.title3).fontWeight(.semibold)
            Text(idea.blurb)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label(idea.place, systemImage: "mappin.circle")
                Label(idea.duration, systemImage: "clock")
                Label(idea.priceRange, systemImage: "dollarsign.circle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Navigate to the rich details page (address/phone/hours/website/etc.)
            NavigationLink {
                IdeaDetailView(idea: idea, locationContext: locationContext)
            } label: {
                Text("Learn More")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AVTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .avCard()
    }
}


struct Wrap: View {
    let tags: [String]
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        VStack { GeometryReader { geo in content(in: geo) } }
            // Min height avoids zero-height GeometryReader passes that can confuse layout math.
            .frame(height: Swift.max(totalHeight.finiteOnly, 1))
    }

    private func content(in g: GeometryProxy) -> some View {
        var w = CGFloat.zero
        var h = CGFloat.zero
        let maxLineWidth = g.size.width.finiteOnly

        return ZStack(alignment: .topLeading) {
            ForEach(tags, id: \.self) { t in
                AVTag(text: t)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .alignmentGuide(.leading) { d in
                        let itemWidth = d.width.finiteOnly
                        let itemHeight = d.height.finiteOnly
                        if maxLineWidth > 0, (w + itemWidth) > maxLineWidth {
                            w = 0
                            h -= itemHeight + 4
                        }
                        let result = w.finiteOnly
                        w = (w + itemWidth + 4).finiteOnly
                        return result
                    }
                    .alignmentGuide(.top) { _ in h.finiteOnly }
            }
        }
        .background(GeometryReader { geo -> Color in
            let h = geo.size.height.finiteOnly
            DispatchQueue.main.async {
                totalHeight = h
            }
            return .clear
        })
    }
}

// MARK: - Supporting Views

// Helper function to extract time from bestTime string and format as "6-8 pm"
private func extractTimeFromBestTime(_ bestTime: String) -> String {
    // Look for time patterns like "6-8 pm", "6:00-8:00 PM", etc.
    let timePatterns = [
        // Pattern: "6-8 pm" or "6-8 PM"
        try? NSRegularExpression(pattern: "(\\d{1,2})-?(\\d{1,2})\\s*(am|pm|AM|PM)", options: .caseInsensitive),
        // Pattern: "6:00-8:00 PM" or "6:00-8:00 pm"
        try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})-?(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)", options: .caseInsensitive),
        // Pattern: "6-8" (just numbers)
        try? NSRegularExpression(pattern: "(\\d{1,2})-?(\\d{1,2})", options: [])
    ]
    
    for pattern in timePatterns {
        if let regex = pattern,
           let match = regex.firstMatch(in: bestTime, range: NSRange(bestTime.startIndex..., in: bestTime)) {
            let range = Range(match.range, in: bestTime)!
            let extractedTime = String(bestTime[range])
            
            // Clean up the extracted time
            let cleanedTime = extractedTime
                .replacingOccurrences(of: "Golden hour", with: "")
                .replacingOccurrences(of: "golden hour", with: "")
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            
            // Format to consistent "6-8 pm" format
            return formatTimeToStandardFormat(cleanedTime)
        }
    }
    
    // If no time pattern found, return the original string
    return bestTime
}

// Helper function to format time to "6-8 pm" format
private func formatTimeToStandardFormat(_ timeString: String) -> String {
    // Remove any existing AM/PM and convert to lowercase
    let cleanTime = timeString
        .replacingOccurrences(of: "AM", with: "am", options: .caseInsensitive)
        .replacingOccurrences(of: "PM", with: "pm", options: .caseInsensitive)
        .trimmingCharacters(in: .whitespaces)
    
    // Extract just the numbers and format as "6-8 pm"
    let numberPattern = try? NSRegularExpression(pattern: "(\\d{1,2})(?::(\\d{2}))?-?(\\d{1,2})(?::(\\d{2}))?", options: [])
    
    if let regex = numberPattern,
       let match = regex.firstMatch(in: cleanTime, range: NSRange(cleanTime.startIndex..., in: cleanTime)) {
        let range = Range(match.range, in: cleanTime)!
        let numbers = String(cleanTime[range])
        
        // Determine if it's PM based on the original string
        let isPM = timeString.lowercased().contains("pm")
        let isAM = timeString.lowercased().contains("am")
        
        // Default to PM if neither AM nor PM is specified (common for evening activities)
        let timeSuffix = isAM ? "am" : (isPM ? "pm" : "pm")
        
        // Format as "6-8 pm" or "6-8 am"
        return "\(numbers) \(timeSuffix)"
    }
    
    return cleanTime
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(16)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
}


