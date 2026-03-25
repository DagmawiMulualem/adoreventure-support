//
//  PreferencesView.swift
//  AdoreVenture
//

import SwiftUI

/// Per-category vibes. `rawValue` is a stable code for caching/Codable; UI uses `displayTitle`.
enum PreferenceVibe: String, Identifiable, Codable, CaseIterable {
    // MARK: Date Ideas
    case dateDiningDrinks = "date_dining_drinks"
    case dateCozyRomantic = "date_cozy_romantic"
    case datePlayfulActive = "date_playful_active"
    case dateCultureArts = "date_culture_arts"
    case dateOutdoorsScenery = "date_outdoors_scenery"

    // MARK: Birthday Ideas
    case bdayPartyGroup = "bday_party_group"
    case bdayDiningCake = "bday_dining_cake"
    case bdayExperienceGift = "bday_experience_gift"
    case bdayNightOut = "bday_night_out"
    case bdayLowKey = "bday_low_key"
    case bdayKidFamily = "bday_kid_family"

    // MARK: Travel & Tourism
    case travelIcons = "travel_icons"
    case travelFoodMarkets = "travel_food_markets"
    case travelCultureHistory = "travel_culture_history"
    case travelNatureDay = "travel_nature_day"
    case travelNeighborhoods = "travel_neighborhoods"

    // MARK: Local Activities
    case localCoffeeHangouts = "local_coffee_hangouts"
    case localLearn = "local_learn"
    case localMoveWellness = "local_move_wellness"
    case localHobbyGames = "local_hobby_games"
    case localOutdoorsNearby = "local_outdoors_nearby"
    case localCommunityEvents = "local_community_events"

    // MARK: Special Events
    case specialHolidaySeasonal = "special_holiday_seasonal"
    case specialTicketsShows = "special_tickets_shows"
    case specialDecoratedPopups = "special_decorated_popups"
    case specialPrivateUpgraded = "special_private_upgraded"
    case specialFamilyEvents = "special_family_events"

    // MARK: Group Activities
    case groupEatDrink = "group_eat_drink"
    case groupGamesCompetition = "group_games_competition"
    case groupOutdoorAdventure = "group_outdoor_adventure"
    case groupTeamBuilding = "group_team_building"
    case groupCulture = "group_culture"

    // MARK: Shared
    case surpriseMe = "surprise_me"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .dateDiningDrinks: return "Dining & drinks"
        case .dateCozyRomantic: return "Cozy & romantic"
        case .datePlayfulActive: return "Playful & active"
        case .dateCultureArts: return "Culture & arts"
        case .dateOutdoorsScenery: return "Outdoors & scenery"
        case .bdayPartyGroup: return "Party & group energy"
        case .bdayDiningCake: return "Dining & cake moments"
        case .bdayExperienceGift: return "Experience gift"
        case .bdayNightOut: return "Night out"
        case .bdayLowKey: return "Low-key celebration"
        case .bdayKidFamily: return "Kid-friendly & family"
        case .travelIcons: return "Icons & must-sees"
        case .travelFoodMarkets: return "Food & markets"
        case .travelCultureHistory: return "Culture & history"
        case .travelNatureDay: return "Nature & day trips"
        case .travelNeighborhoods: return "Neighborhoods & local life"
        case .localCoffeeHangouts: return "Coffee & hangouts"
        case .localLearn: return "Learn something"
        case .localMoveWellness: return "Move & wellness"
        case .localHobbyGames: return "Hobby & games"
        case .localOutdoorsNearby: return "Outdoors nearby"
        case .localCommunityEvents: return "Community & events"
        case .specialHolidaySeasonal: return "Holiday & seasonal"
        case .specialTicketsShows: return "Tickets & shows"
        case .specialDecoratedPopups: return "Decorated venues & pop-ups"
        case .specialPrivateUpgraded: return "Private & upgraded"
        case .specialFamilyEvents: return "Family-friendly events"
        case .groupEatDrink: return "Eat & drink together"
        case .groupGamesCompetition: return "Games & competition"
        case .groupOutdoorAdventure: return "Outdoor & adventure"
        case .groupTeamBuilding: return "Team building"
        case .groupCulture: return "Culture as a group"
        case .surpriseMe: return "Surprise me"
        }
    }

    var emoji: String {
        switch self {
        case .dateDiningDrinks, .bdayDiningCake, .travelFoodMarkets, .groupEatDrink: return "🍽"
        case .dateCozyRomantic: return "🕯"
        case .datePlayfulActive, .groupGamesCompetition: return "🎯"
        case .dateCultureArts, .travelCultureHistory, .groupCulture: return "🎨"
        case .dateOutdoorsScenery, .travelNatureDay, .localOutdoorsNearby, .groupOutdoorAdventure: return "🌿"
        case .bdayPartyGroup: return "🎉"
        case .bdayExperienceGift: return "🎁"
        case .bdayNightOut: return "🌃"
        case .bdayLowKey: return "☕️"
        case .bdayKidFamily: return "🧸"
        case .travelIcons: return "🗽"
        case .travelNeighborhoods: return "🚶"
        case .localCoffeeHangouts: return "☕️"
        case .localLearn: return "📚"
        case .localMoveWellness: return "💪"
        case .localHobbyGames: return "🎮"
        case .localCommunityEvents: return "👋"
        case .specialHolidaySeasonal: return "🎄"
        case .specialTicketsShows: return "🎟"
        case .specialDecoratedPopups: return "✨"
        case .specialPrivateUpgraded: return "🥂"
        case .specialFamilyEvents: return "👨‍👩‍👧"
        case .groupTeamBuilding: return "🤝"
        case .surpriseMe: return "🎲"
        }
    }

    /// AI-facing text; `category` only refines `surpriseMe`.
    func promptLabel(for category: AVCategory) -> String {
        switch self {
        case .surpriseMe:
            return "Surprise me (varied mix appropriate for \(category.rawValue), not limited to one vibe)"
        case .dateDiningDrinks:
            return "Dining & drinks — restaurants, wine bars, dessert spots, rooftops; food-forward date"
        case .dateCozyRomantic:
            return "Cozy & romantic — intimate venues, sunset views, slow evenings, conversation-first"
        case .datePlayfulActive:
            return "Playful & active — mini golf, games, skating, hands-on fun together"
        case .dateCultureArts:
            return "Culture & arts — museums, live music, comedy, galleries, performances"
        case .dateOutdoorsScenery:
            return "Outdoors & scenery — walks, waterfront, viewpoints, light nature (still date-worthy for two)"
        case .bdayPartyGroup:
            return "Party & group energy — celebratory venues and group-friendly birthday vibes"
        case .bdayDiningCake:
            return "Dining & cake moments — brunch, dinner, dessert bars, private rooms, birthday meal focus"
        case .bdayExperienceGift:
            return "Experience gift — class, workshop, spa, or memorable activity as the celebration"
        case .bdayNightOut:
            return "Night out — show, live music, karaoke, bars (age-appropriate celebration)"
        case .bdayLowKey:
            return "Low-key celebration — picnic, scenic walk, small gathering spots"
        case .bdayKidFamily:
            return "Kid-friendly & family — birthday ideas that work well with children or multi-age family"
        case .travelIcons:
            return "Icons & must-sees — landmarks and classic sights visitors expect"
        case .travelFoodMarkets:
            return "Food & markets — food tours, markets, local specialties"
        case .travelCultureHistory:
            return "Culture & history — museums, guided tours, heritage sites"
        case .travelNatureDay:
            return "Nature & day trips — parks, hikes, beaches, scenic viewpoints"
        case .travelNeighborhoods:
            return "Neighborhoods & local life — districts, cafés, everyday local texture (for visitors)"
        case .localCoffeeHangouts:
            return "Coffee & hangouts — cafés, casual meetup spots, neighborhood vibe"
        case .localLearn:
            return "Learn something — classes, talks, workshops, skill-building"
        case .localMoveWellness:
            return "Move & wellness — fitness-adjacent, yoga, courts, active local options"
        case .localHobbyGames:
            return "Hobby & games — board game cafés, VR, trivia, leagues"
        case .localOutdoorsNearby:
            return "Outdoors nearby — local parks, trails, dog-friendly outdoor spots"
        case .localCommunityEvents:
            return "Community & events — markets, fairs, local meetups"
        case .specialHolidaySeasonal:
            return "Holiday & seasonal — tied to calendar holidays or seasonal occasions"
        case .specialTicketsShows:
            return "Tickets & shows — timed events: concerts, sports, theater"
        case .specialDecoratedPopups:
            return "Decorated venues & pop-ups — themed bars, installations, seasonal pop-ups"
        case .specialPrivateUpgraded:
            return "Private & upgraded — private dining, suites, elevated special-occasion formats"
        case .specialFamilyEvents:
            return "Family-friendly events — parades, festivals, daytime occasion-friendly"
        case .groupEatDrink:
            return "Eat & drink together — group dining, breweries, food halls (3+ people)"
        case .groupGamesCompetition:
            return "Games & competition — escape rooms, bowling, arcades, laser tag, group play"
        case .groupOutdoorAdventure:
            return "Outdoor & adventure — group-friendly hikes, boating, beach day, adventure parks"
        case .groupTeamBuilding:
            return "Team building — light cooperative challenges suitable for teams or large friend groups"
        case .groupCulture:
            return "Culture as a group — group tours, museums, shows suited to 3+ together"
        }
    }

    static func options(for category: AVCategory) -> [PreferenceVibe] {
        switch category {
        case .date:
            return [.dateDiningDrinks, .dateCozyRomantic, .datePlayfulActive, .dateCultureArts, .dateOutdoorsScenery, .surpriseMe]
        case .birthday:
            return [.bdayPartyGroup, .bdayDiningCake, .bdayExperienceGift, .bdayNightOut, .bdayLowKey, .bdayKidFamily, .surpriseMe]
        case .travel:
            return [.travelIcons, .travelFoodMarkets, .travelCultureHistory, .travelNatureDay, .travelNeighborhoods, .surpriseMe]
        case .local:
            return [.localCoffeeHangouts, .localLearn, .localMoveWellness, .localHobbyGames, .localOutdoorsNearby, .localCommunityEvents, .surpriseMe]
        case .special:
            return [.specialHolidaySeasonal, .specialTicketsShows, .specialDecoratedPopups, .specialPrivateUpgraded, .specialFamilyEvents, .surpriseMe]
        case .group:
            return [.groupEatDrink, .groupGamesCompetition, .groupOutdoorAdventure, .groupTeamBuilding, .groupCulture, .surpriseMe]
        }
    }
}

enum PreferenceBudget: String, CaseIterable, Identifiable, Codable {
    case free = "Free"
    case freeAndPaid = "Free & paid"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .free: return "🆓"
        case .freeAndPaid: return "💰"
        }
    }

    var backendHint: String {
        switch self {
        case .free: return "Free / $0 options only"
        case .freeAndPaid:
            return "No budget preference — suggest the best options regardless of cost (free, low-cost, or pricier as fits)"
        }
    }
}

struct SearchPreferences: Codable, Equatable {
    var vibes: Set<PreferenceVibe> = []
    var budget: PreferenceBudget?

    var isEmpty: Bool {
        vibes.isEmpty && budget == nil
    }

    var cacheKeySuffix: String {
        let vibePart = vibes.map(\.rawValue).sorted().joined(separator: ",")
        let budgetPart = budget?.rawValue ?? "none"
        return "v:\(vibePart)|b:\(budgetPart)"
    }

    var budgetHint: String? {
        budget?.backendHint
    }

    func indoorOutdoorHint(for category: AVCategory) -> String? {
        guard !vibes.isEmpty else { return nil }
        let names = vibes.map { $0.promptLabel(for: category) }.sorted().joined(separator: ", ")
        return "Vibe: \(names)"
    }
}

private enum PreferenceCardKind: Int, CaseIterable, Identifiable {
    case vibe = 0
    case budget = 1

    var id: Int { rawValue }
}

struct PreferencesView: View {
    private let maxVibeSelections = 2

    let location: String
    let category: AVCategory

    @State private var selectedVibes: Set<PreferenceVibe> = []
    @State private var selectedBudget: PreferenceBudget?
    /// 0 = vibe, 1 = budget, 2 = all done.
    @State private var activeStep: Int = 0

    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    private var vibeOptions: [PreferenceVibe] {
        PreferenceVibe.options(for: category)
    }

    private var builtPreferences: SearchPreferences? {
        let prefs = SearchPreferences(
            vibes: selectedVibes,
            budget: selectedBudget
        )
        return prefs.isEmpty ? nil : prefs
    }

    private var preferencesReady: Bool {
        !selectedVibes.isEmpty && selectedBudget != nil
    }

    private var vibeSummary: String {
        if selectedVibes.isEmpty { return "Pick up to \(maxVibeSelections)" }
        if selectedVibes.count == 1 { return selectedVibes.first?.displayTitle ?? "1 selected" }
        return selectedVibes.map(\.displayTitle).sorted().joined(separator: " · ")
    }

    private var budgetSummary: String {
        selectedBudget?.rawValue ?? "Tap to choose"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set Your Preferences")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Help us personalize your \(category.rawValue.lowercased()) for \(location)")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 16) {
                    accordionCard(.vibe, title: "Vibe", subtitle: vibeSummary, icon: "sparkles") {
                        VStack(spacing: 8) {
                            Text("Pick up to \(maxVibeSelections)")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(vibeOptions) { vibe in
                                let atMax = selectedVibes.count >= maxVibeSelections
                                let rowDisabled = atMax && !selectedVibes.contains(vibe)
                                optionRow(
                                    emoji: vibe.emoji,
                                    title: vibe.displayTitle,
                                    selected: selectedVibes.contains(vibe),
                                    disabled: rowDisabled
                                ) {
                                    if selectedVibes.contains(vibe) {
                                        selectedVibes.remove(vibe)
                                    } else if selectedVibes.count < maxVibeSelections {
                                        selectedVibes.insert(vibe)
                                    }
                                }
                            }
                            Button {
                                guard !selectedVibes.isEmpty else { return }
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    activeStep = 1
                                }
                            } label: {
                                Text("Continue")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedVibes.isEmpty ? Color.white.opacity(0.12) : AVTheme.accent)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedVibes.isEmpty)
                            .padding(.top, 4)
                        }
                    }

                    accordionCard(.budget, title: "Budget", subtitle: budgetSummary, icon: "dollarsign.circle") {
                        VStack(spacing: 8) {
                            ForEach(PreferenceBudget.allCases) { budget in
                                optionRow(
                                    emoji: budget.emoji,
                                    title: budget.rawValue,
                                    selected: selectedBudget == budget
                                ) {
                                    selectedBudget = budget
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        activeStep = 2
                                    }
                                }
                            }
                        }
                    }
                }

                NavigationLink {
                    IdeasListView(
                        location: location,
                        category: category,
                        ideas: [],
                        preferences: builtPreferences,
                        autoFetch: true
                    )
                    .environmentObject(firebaseManager)
                    .environmentObject(subscriptionManager)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                        Text("See Ideas")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(preferencesReady ? AVTheme.accent : Color.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!preferencesReady)
                .opacity(preferencesReady ? 1 : 0.55)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func accordionCard<Content: View>(
        _ kind: PreferenceCardKind,
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let expanded = activeStep == kind.rawValue
        let stepIndex = kind.rawValue
        let isLocked = activeStep < stepIndex

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isLocked ? .white.opacity(0.35) : AVTheme.accent)
                    .frame(width: 32, height: 32)
                    .background((isLocked ? Color.white.opacity(0.06) : AVTheme.accent.opacity(0.15)))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer(minLength: 8)

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(isLocked ? 0.25 : 0.75))
            }

            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(isLocked ? .white.opacity(0.35) : .white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(isLocked ? .white.opacity(0.28) : .white.opacity(0.72))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if expanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: expanded ? nil : 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(isLocked ? 0.04 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            expanded ? AVTheme.accent : Color.white.opacity(isLocked ? 0.04 : 0.08),
                            lineWidth: expanded ? 2 : 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .allowsHitTesting(!isLocked)
        .onTapGesture {
            guard !expanded, !isLocked else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                activeStep = kind.rawValue
            }
        }
    }

    private func optionRow(emoji: String, title: String, selected: Bool, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AVTheme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected ? AVTheme.accent.opacity(0.16) : Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? AVTheme.accent : Color.white.opacity(0.06), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(selected ? AVTheme.accent : .white)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
    }
}
