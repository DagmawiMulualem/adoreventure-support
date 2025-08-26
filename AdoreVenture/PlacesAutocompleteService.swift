//
//  PlacesAutocompleteService.swift
//  AdoreVenture
//

import Foundation
import SwiftUI

// MARK: - Places Autocomplete Models

struct PlacePrediction: Identifiable, Hashable {
    let id = UUID()
    let placeId: String
    let description: String
    let mainText: String
    let secondaryText: String
    
    init(placeId: String, description: String) {
        self.placeId = placeId
        self.description = description
        
        // Parse description to extract main and secondary text
        let components = description.components(separatedBy: ", ")
        if components.count >= 2 {
            self.mainText = components[0]
            self.secondaryText = components.dropFirst().joined(separator: ", ")
        } else {
            self.mainText = description
            self.secondaryText = ""
        }
    }
}

struct PlacesAutocompleteResponse: Codable {
    let predictions: [Prediction]
    let status: String
    
    struct Prediction: Codable {
        let placeId: String
        let description: String
        let structuredFormatting: StructuredFormatting
        
        enum CodingKeys: String, CodingKey {
            case placeId = "place_id"
            case description
            case structuredFormatting = "structured_formatting"
        }
        
        struct StructuredFormatting: Codable {
            let mainText: String
            let secondaryText: String
            
            enum CodingKeys: String, CodingKey {
                case mainText = "main_text"
                case secondaryText = "secondary_text"
            }
        }
    }
}

// MARK: - Places Autocomplete Service

class PlacesAutocompleteService: ObservableObject {
    @Published var predictions: [PlacePrediction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiKey = "AIzaSyDxqPgIc7zWlcOru2FkOYzR3iL-tKPnlIM"
    private let baseURL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
    
    func searchPlaces(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.predictions = []
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Add a small delay to avoid too many API calls
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "input", value: encodedQuery),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "types", value: "(cities)"), // Focus on cities and countries
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "sessiontoken", value: UUID().uuidString) // Prevent bias from previous searches
        ]
        
        guard let url = components?.url else {
            await MainActor.run {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.errorMessage = "Network error"
                    self.isLoading = false
                }
                return
            }
            
            let placesResponse = try JSONDecoder().decode(PlacesAutocompleteResponse.self, from: data)
            
            await MainActor.run {
                if placesResponse.status == "OK" {
                    print("🔍 Places API returned \(placesResponse.predictions.count) predictions")
                    
                    // Filter predictions to only include relevant results
                    let relevantPredictions = placesResponse.predictions.filter { prediction in
                        let description = prediction.description.lowercased()
                        let mainText = prediction.structuredFormatting.mainText.lowercased()
                        let query = query.lowercased()
                        
                        // Very strict filtering - only show results that actually match the query
                        let isRelevant = mainText.hasPrefix(query) || 
                                        mainText.contains(query) ||
                                        description.contains(query)
                        
                        // Additional check: if query is a country name, prioritize it
                        let isCountryQuery = ["japan", "ethiopia", "france", "germany", "italy", "spain", "brazil", "china", "india", "australia", "canada", "mexico", "uk", "england", "russia", "south africa", "egypt", "morocco", "kenya", "nigeria", "ghana", "uganda", "tanzania", "zimbabwe", "zambia", "malawi", "mozambique", "angola", "namibia", "botswana", "lesotho", "swaziland", "madagascar", "mauritius", "seychelles", "comoros", "mayotte", "reunion", "djibouti", "somalia", "eritrea", "sudan", "south sudan", "central african republic", "chad", "niger", "mali", "burkina faso", "senegal", "gambia", "guinea-bissau", "guinea", "sierra leone", "liberia", "ivory coast", "togo", "benin", "cameroon", "equatorial guinea", "gabon", "congo", "democratic republic of the congo", "burundi", "rwanda"].contains(query)
                        
                        if isCountryQuery {
                            // For country queries, be very strict
                            return isRelevant && (mainText == query || description.contains(query))
                        }
                        
                        print("🔍 Checking: '\(prediction.structuredFormatting.mainText)' - Relevant: \(isRelevant)")
                        
                        return isRelevant
                    }
                    
                    print("🔍 Filtered to \(relevantPredictions.count) relevant predictions")
                    
                    self.predictions = relevantPredictions.map { prediction in
                        PlacePrediction(
                            placeId: prediction.placeId,
                            description: prediction.description
                        )
                    }
                } else {
                    print("🔍 Places API status: \(placesResponse.status)")
                    self.errorMessage = "No results found"
                    self.predictions = []
                }
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch suggestions"
                self.isLoading = false
            }
        }
    }
    
    func clearPredictions() {
        predictions = []
        errorMessage = nil
    }
}

// MARK: - Places Autocomplete View

struct PlacesAutocompleteView: View {
    @Binding var searchText: String
    @Binding var selectedLocation: String
    @ObservedObject var placesService: PlacesAutocompleteService
    let onLocationSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if placesService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            } else if !placesService.predictions.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(placesService.predictions) { prediction in
                            Button {
                                selectedLocation = prediction.mainText
                                searchText = prediction.mainText
                                onLocationSelected(prediction.mainText)
                                placesService.clearPredictions()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(prediction.mainText)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if !prediction.secondaryText.isEmpty {
                                        Text(prediction.secondaryText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            
                            if prediction.id != placesService.predictions.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
        }
    }
}
