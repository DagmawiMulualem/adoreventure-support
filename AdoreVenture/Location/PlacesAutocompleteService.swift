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
        
        // Try multiple search strategies for better coverage
        await performSearchWithFallback(query: query)
    }
    
    private func performSearchWithFallback(query: String) async {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Strategy 1: Search without type restrictions
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "input", value: encodedQuery),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "sessiontoken", value: UUID().uuidString),
            URLQueryItem(name: "components", value: "country:*")
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
            
            // If first strategy didn't work well, try with different parameters
            if placesResponse.status != "OK" || placesResponse.predictions.count < 2 {
                await tryAlternativeSearch(query: query)
                return
            }
            
            await MainActor.run {
                if placesResponse.status == "OK" {
                    print("🔍 Places API returned \(placesResponse.predictions.count) predictions")
                    
                    // Simplified and more inclusive filtering
                    let relevantPredictions = placesResponse.predictions.filter { prediction in
                        let description = prediction.description.lowercased()
                        let mainText = prediction.structuredFormatting.mainText.lowercased()
                        let query = query.lowercased()
                        
                        // More inclusive matching - check if any part matches
                        let isRelevant = mainText.hasPrefix(query) || 
                                        mainText.contains(query) ||
                                        description.contains(query) ||
                                        // Check if query is contained within the main text (for partial matches)
                                        query.split(separator: " ").allSatisfy { word in
                                            mainText.contains(word) || description.contains(word)
                                        }
                        
                        print("🔍 Checking: '\(prediction.structuredFormatting.mainText)' - Relevant: \(isRelevant)")
                        
                        return isRelevant
                    }
                    
                    print("🔍 Filtered to \(relevantPredictions.count) relevant predictions")
                    
                    var apiPredictions = relevantPredictions.map { prediction in
                        PlacePrediction(
                            placeId: prediction.placeId,
                            description: prediction.description
                        )
                    }
                    
                    // Add fallback results if API didn't return enough results
                    if apiPredictions.count < 3 {
                        let fallbackResults = self.getFallbackResults(for: query)
                        apiPredictions.append(contentsOf: fallbackResults)
                    }
                    
                    self.predictions = apiPredictions
                } else {
                    print("🔍 Places API status: \(placesResponse.status)")
                    // Use fallback results when API fails
                    let fallbackResults = self.getFallbackResults(for: query)
                    if fallbackResults.isEmpty {
                        self.errorMessage = "No results found"
                    }
                    self.predictions = fallbackResults
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
    
    // Fallback list as pairs (allows harmless duplicates without crashing)
    private let fallbackPlacesPairs: [(String, String)] = [
        // --- Major African Cities ---
        ("addis ababa", "Addis Ababa, Ethiopia"),
        ("nairobi", "Nairobi, Kenya"),
        ("lagos", "Lagos, Nigeria"),
        ("cairo", "Cairo, Egypt"),
        ("casablanca", "Casablanca, Morocco"),
        ("johannesburg", "Johannesburg, South Africa"),
        ("cape town", "Cape Town, South Africa"),
        ("dar es salaam", "Dar es Salaam, Tanzania"),
        ("accra", "Accra, Ghana"),
        ("kinshasa", "Kinshasa, Democratic Republic of the Congo"),
        ("luanda", "Luanda, Angola"),
        ("alexandria", "Alexandria, Egypt"),
        ("giza", "Giza, Egypt"),
        ("rabat", "Rabat, Morocco"),
        ("marrakech", "Marrakech, Morocco"),
        ("fes", "Fes, Morocco"),
        ("tunis", "Tunis, Tunisia"),
        ("algiers", "Algiers, Algeria"),
        ("tripoli", "Tripoli, Libya"),
        ("khartoum", "Khartoum, Sudan"),
        ("juba", "Juba, South Sudan"),
        ("djibouti", "Djibouti, Djibouti"), // city
        ("mogadishu", "Mogadishu, Somalia"),
        ("asmara", "Asmara, Eritrea"), // fixed spelling from "asmera"
        ("bujumbura", "Bujumbura, Burundi"),
        ("kigali", "Kigali, Rwanda"),
        ("kampala", "Kampala, Uganda"),
        ("dodoma", "Dodoma, Tanzania"),
        ("zanzibar", "Zanzibar, Tanzania"),
        ("mombasa", "Mombasa, Kenya"),
        ("nakuru", "Nakuru, Kenya"),
        ("kisumu", "Kisumu, Kenya"),
        ("eldoret", "Eldoret, Kenya"),
        ("thika", "Thika, Kenya"),
        ("kakamega", "Kakamega, Kenya"),
        ("kericho", "Kericho, Kenya"),
        ("kisii", "Kisii, Kenya"),
        ("nyeri", "Nyeri, Kenya"),
        ("machakos", "Machakos, Kenya"),
        ("embu", "Embu, Kenya"),
        ("meru", "Meru, Kenya"),
        ("nanyuki", "Nanyuki, Kenya"),
        ("lamu", "Lamu, Kenya"),
        ("malindi", "Malindi, Kenya"),
        ("watamu", "Watamu, Kenya"),
        ("diani", "Diani, Kenya"),
        ("kilifi", "Kilifi, Kenya"),
        ("vanga", "Vanga, Kenya"),
        ("shimoni", "Shimoni, Kenya"),
        ("wasini", "Wasini, Kenya"),
        ("funzi", "Funzi, Kenya"),
        ("gazi", "Gazi, Kenya"),
        ("msambweni", "Msambweni, Kenya"),
        ("ukunda", "Ukunda, Kenya"),
        ("tiwi", "Tiwi, Kenya"),
        ("kwale", "Kwale, Kenya"),
        ("lunga lunga", "Lunga Lunga, Kenya"),

        // --- Major World Cities ---
        ("new york", "New York, NY, USA"),
        ("london", "London, UK"),
        ("paris", "Paris, France"),
        ("tokyo", "Tokyo, Japan"),
        ("beijing", "Beijing, China"),
        ("shanghai", "Shanghai, China"),
        ("mumbai", "Mumbai, India"),
        ("delhi", "Delhi, India"),
        ("sao paulo", "São Paulo, Brazil"),
        ("mexico city", "Mexico City, Mexico"),
        ("sydney", "Sydney, Australia"),
        ("melbourne", "Melbourne, Australia"),
        ("toronto", "Toronto, Canada"),
        ("vancouver", "Vancouver, Canada"),
        ("montreal", "Montreal, Canada"),
        
        // --- Additional Major World Cities ---
        ("los angeles", "Los Angeles, CA, USA"),
        ("chicago", "Chicago, IL, USA"),
        ("houston", "Houston, TX, USA"),
        ("phoenix", "Phoenix, AZ, USA"),
        ("philadelphia", "Philadelphia, PA, USA"),
        ("san antonio", "San Antonio, TX, USA"),
        ("san diego", "San Diego, CA, USA"),
        ("dallas", "Dallas, TX, USA"),
        ("san jose", "San Jose, CA, USA"),
        ("austin", "Austin, TX, USA"),
        ("jacksonville", "Jacksonville, FL, USA"),
        ("fort worth", "Fort Worth, TX, USA"),
        ("columbus", "Columbus, OH, USA"),
        ("charlotte", "Charlotte, NC, USA"),
        ("san francisco", "San Francisco, CA, USA"),
        ("indianapolis", "Indianapolis, IN, USA"),
        ("seattle", "Seattle, WA, USA"),
        ("denver", "Denver, CO, USA"),
        ("washington dc", "Washington, DC, USA"),
        ("boston", "Boston, MA, USA"),
        ("el paso", "El Paso, TX, USA"),
        ("nashville", "Nashville, TN, USA"),
        ("detroit", "Detroit, MI, USA"),
        ("oklahoma city", "Oklahoma City, OK, USA"),
        ("portland", "Portland, OR, USA"),
        ("las vegas", "Las Vegas, NV, USA"),
        ("memphis", "Memphis, TN, USA"),
        ("louisville", "Louisville, KY, USA"),
        ("baltimore", "Baltimore, MD, USA"),
        ("milwaukee", "Milwaukee, WI, USA"),
        ("albuquerque", "Albuquerque, NM, USA"),
        ("tucson", "Tucson, AZ, USA"),
        ("fresno", "Fresno, CA, USA"),
        ("sacramento", "Sacramento, CA, USA"),
        ("atlanta", "Atlanta, GA, USA"),
        ("kansas city", "Kansas City, MO, USA"),
        ("long beach", "Long Beach, CA, USA"),
        ("colorado springs", "Colorado Springs, CO, USA"),
        ("raleigh", "Raleigh, NC, USA"),
        ("miami", "Miami, FL, USA"),
        ("virginia beach", "Virginia Beach, VA, USA"),
        ("omaha", "Omaha, NE, USA"),
        ("oakland", "Oakland, CA, USA"),
        ("minneapolis", "Minneapolis, MN, USA"),
        ("tulsa", "Tulsa, OK, USA"),
        ("arlington", "Arlington, TX, USA"),
        ("tampa", "Tampa, FL, USA"),
        ("new orleans", "New Orleans, LA, USA"),
        ("wichita", "Wichita, KS, USA"),
        ("cleveland", "Cleveland, OH, USA"),
        ("bakersfield", "Bakersfield, CA, USA"),
        ("aurora", "Aurora, CO, USA"),
        ("anaheim", "Anaheim, CA, USA"),
        ("honolulu", "Honolulu, HI, USA"),
        ("santa ana", "Santa Ana, CA, USA"),
        ("corpus christi", "Corpus Christi, TX, USA"),
        ("riverside", "Riverside, CA, USA"),
        ("lexington", "Lexington, KY, USA"),
        ("stockton", "Stockton, CA, USA"),
        ("henderson", "Henderson, NV, USA"),
        ("saint paul", "Saint Paul, MN, USA"),
        ("st. paul", "Saint Paul, MN, USA"),
        ("st louis", "St. Louis, MO, USA"),
        ("cincinnati", "Cincinnati, OH, USA"),
        ("pittsburgh", "Pittsburgh, PA, USA"),
        ("greensboro", "Greensboro, NC, USA"),
        ("anchorage", "Anchorage, AK, USA"),
        ("plano", "Plano, TX, USA"),
        ("orlando", "Orlando, FL, USA"),
        ("newark", "Newark, NJ, USA"),
        ("durham", "Durham, NC, USA"),
        ("chula vista", "Chula Vista, CA, USA"),
        ("toledo", "Toledo, OH, USA"),
        ("fort wayne", "Fort Wayne, IN, USA"),
        ("st. petersburg", "St. Petersburg, FL, USA"),
        ("laredo", "Laredo, TX, USA"),
        ("chandler", "Chandler, AZ, USA"),
        ("norfolk", "Norfolk, VA, USA"),
        ("garland", "Garland, TX, USA"),
        ("glendale", "Glendale, AZ, USA"),
        ("baton rouge", "Baton Rouge, LA, USA"),
        ("hialeah", "Hialeah, FL, USA"),
        ("madison", "Madison, WI, USA"),
        ("lubbock", "Lubbock, TX, USA"),
        ("laredo", "Laredo, TX, USA"),
        ("irvine", "Irvine, CA, USA"),
        ("chesapeake", "Chesapeake, VA, USA"),
        ("gilbert", "Gilbert, AZ, USA"),
        ("birmingham", "Birmingham, AL, USA"),
        ("rochester", "Rochester, NY, USA"),
        ("spokane", "Spokane, WA, USA"),
        ("arlington", "Arlington, VA, USA"),
        ("montgomery", "Montgomery, AL, USA"),
        ("des moines", "Des Moines, IA, USA"),
        ("richmond", "Richmond, VA, USA"),
        ("yuma", "Yuma, AZ, USA"),
        ("shreveport", "Shreveport, LA, USA"),
        ("akron", "Akron, OH, USA"),
        ("huntington beach", "Huntington Beach, CA, USA"),
        ("little rock", "Little Rock, AR, USA"),
        ("augusta", "Augusta, GA, USA"),
        ("salt lake city", "Salt Lake City, UT, USA"),
        ("grand rapids", "Grand Rapids, MI, USA"),
        ("tallahassee", "Tallahassee, FL, USA"),
        ("overland park", "Overland Park, KS, USA"),
        ("grand prairie", "Grand Prairie, TX, USA"),
        ("winston salem", "Winston-Salem, NC, USA"),
        ("knoxville", "Knoxville, TN, USA"),
        ("worcester", "Worcester, MA, USA"),
        ("brownsville", "Brownsville, TX, USA"),
        ("oxnard", "Oxnard, CA, USA"),
        ("santa clarita", "Santa Clarita, CA, USA"),
        ("garden grove", "Garden Grove, CA, USA"),
        ("ontario", "Ontario, CA, USA"),
        ("vancouver", "Vancouver, WA, USA"),
        ("tempe", "Tempe, AZ, USA"),
        ("springfield", "Springfield, MO, USA"),
        ("pembroke pines", "Pembroke Pines, FL, USA"),
        ("elk grove", "Elk Grove, CA, USA"),
        ("rancho cucamonga", "Rancho Cucamonga, CA, USA"),
        ("cape coral", "Cape Coral, FL, USA"),
        ("peoria", "Peoria, AZ, USA"),
        ("mesa", "Mesa, AZ, USA"),
        ("sioux falls", "Sioux Falls, SD, USA"),
        ("new york city", "New York, NY, USA"),
        ("nyc", "New York, NY, USA"),
        ("la", "Los Angeles, CA, USA"),
        ("sf", "San Francisco, CA, USA"),
        ("dc", "Washington, DC, USA"),
        ("vegas", "Las Vegas, NV, USA"),

        // --- Major International Cities ---
        ("madrid", "Madrid, Spain"),
        ("barcelona", "Barcelona, Spain"),
        ("rome", "Rome, Italy"),
        ("milan", "Milan, Italy"),
        ("venice", "Venice, Italy"),
        ("florence", "Florence, Italy"),
        ("naples", "Naples, Italy"),
        ("amsterdam", "Amsterdam, Netherlands"),
        ("rotterdam", "Rotterdam, Netherlands"),
        ("brussels", "Brussels, Belgium"),
        ("antwerp", "Antwerp, Belgium"),
        ("zurich", "Zurich, Switzerland"),
        ("geneva", "Geneva, Switzerland"),
        ("basel", "Basel, Switzerland"),
        ("vienna", "Vienna, Austria"),
        ("salzburg", "Salzburg, Austria"),
        ("stockholm", "Stockholm, Sweden"),
        ("gothenburg", "Gothenburg, Sweden"),
        ("oslo", "Oslo, Norway"),
        ("bergen", "Bergen, Norway"),
        ("copenhagen", "Copenhagen, Denmark"),
        ("aarhus", "Aarhus, Denmark"),
        ("helsinki", "Helsinki, Finland"),
        ("tampere", "Tampere, Finland"),
        ("warsaw", "Warsaw, Poland"),
        ("krakow", "Krakow, Poland"),
        ("gdansk", "Gdansk, Poland"),
        ("prague", "Prague, Czech Republic"),
        ("brno", "Brno, Czech Republic"),
        ("budapest", "Budapest, Hungary"),
        ("debrecen", "Debrecen, Hungary"),
        ("bucharest", "Bucharest, Romania"),
        ("cluj napoca", "Cluj-Napoca, Romania"),
        ("sofia", "Sofia, Bulgaria"),
        ("plovdiv", "Plovdiv, Bulgaria"),
        ("athens", "Athens, Greece"),
        ("thessaloniki", "Thessaloniki, Greece"),
        ("istanbul", "Istanbul, Turkey"),
        ("ankara", "Ankara, Turkey"),
        ("izmir", "Izmir, Turkey"),
        ("moscow", "Moscow, Russia"),
        ("saint petersburg", "Saint Petersburg, Russia"),
        ("novosibirsk", "Novosibirsk, Russia"),
        ("yekaterinburg", "Yekaterinburg, Russia"),
        ("kiev", "Kiev, Ukraine"),
        ("kharkiv", "Kharkiv, Ukraine"),
        ("odessa", "Odessa, Ukraine"),
        ("minsk", "Minsk, Belarus"),
        ("vilnius", "Vilnius, Lithuania"),
        ("riga", "Riga, Latvia"),
        ("tallinn", "Tallinn, Estonia"),
        ("seoul", "Seoul, South Korea"),
        ("busan", "Busan, South Korea"),
        ("incheon", "Incheon, South Korea"),
        ("daegu", "Daegu, South Korea"),
        ("daejeon", "Daejeon, South Korea"),
        ("gwangju", "Gwangju, South Korea"),
        ("suwon", "Suwon, South Korea"),
        ("ulsan", "Ulsan, South Korea"),
        ("bucheon", "Bucheon, South Korea"),
        ("seongnam", "Seongnam, South Korea"),
        ("jeju", "Jeju, South Korea"),
        ("pyongyang", "Pyongyang, North Korea"),
        ("ulaanbaatar", "Ulaanbaatar, Mongolia"),
        ("almaty", "Almaty, Kazakhstan"),
        ("nur sultan", "Nur-Sultan, Kazakhstan"),
        ("astana", "Nur-Sultan, Kazakhstan"),
        ("tashkent", "Tashkent, Uzbekistan"),
        ("samarkand", "Samarkand, Uzbekistan"),
        ("bishkek", "Bishkek, Kyrgyzstan"),
        ("osh", "Osh, Kyrgyzstan"),
        ("dushanbe", "Dushanbe, Tajikistan"),
        ("ashgabat", "Ashgabat, Turkmenistan"),
        ("kabul", "Kabul, Afghanistan"),
        ("tehran", "Tehran, Iran"),
        ("mashhad", "Mashhad, Iran"),
        ("isfahan", "Isfahan, Iran"),
        ("tabriz", "Tabriz, Iran"),
        ("shiraz", "Shiraz, Iran"),
        ("baghdad", "Baghdad, Iraq"),
        ("basra", "Basra, Iraq"),
        ("mosul", "Mosul, Iraq"),
        ("damascus", "Damascus, Syria"),
        ("aleppo", "Aleppo, Syria"),
        ("beirut", "Beirut, Lebanon"),
        ("amman", "Amman, Jordan"),
        ("jerusalem", "Jerusalem, Israel"),
        ("tel aviv", "Tel Aviv, Israel"),
        ("haifa", "Haifa, Israel"),
        ("ramallah", "Ramallah, Palestine"),
        ("gaza", "Gaza, Palestine"),
        ("riyadh", "Riyadh, Saudi Arabia"),
        ("jeddah", "Jeddah, Saudi Arabia"),
        ("mecca", "Mecca, Saudi Arabia"),
        ("medina", "Medina, Saudi Arabia"),
        ("dammam", "Dammam, Saudi Arabia"),
        ("sanaa", "Sanaa, Yemen"),
        ("aden", "Aden, Yemen"),
        ("muscat", "Muscat, Oman"),
        ("salalah", "Salalah, Oman"),
        ("dubai", "Dubai, UAE"),
        ("abu dhabi", "Abu Dhabi, UAE"),
        ("sharjah", "Sharjah, UAE"),
        ("ajman", "Ajman, UAE"),
        ("doha", "Doha, Qatar"),
        ("al kuwait", "Kuwait City, Kuwait"),
        ("kuwait city", "Kuwait City, Kuwait"),
        ("manama", "Manama, Bahrain"),
        ("nicosia", "Nicosia, Cyprus"),
        ("limassol", "Limassol, Cyprus"),
        ("valletta", "Valletta, Malta"),
        ("reykjavik", "Reykjavik, Iceland"),
        ("dublin", "Dublin, Ireland"),
        ("cork", "Cork, Ireland"),
        ("galway", "Galway, Ireland"),
        ("edinburgh", "Edinburgh, Scotland, UK"),
        ("glasgow", "Glasgow, Scotland, UK"),
        ("aberdeen", "Aberdeen, Scotland, UK"),
        ("cardiff", "Cardiff, Wales, UK"),
        ("swansea", "Swansea, Wales, UK"),
        ("belfast", "Belfast, Northern Ireland, UK"),
        ("derry", "Derry, Northern Ireland, UK"),

        // --- Major Asian Cities ---
        ("hong kong", "Hong Kong"),
        ("singapore", "Singapore"),
        ("bangkok", "Bangkok, Thailand"),
        ("chiang mai", "Chiang Mai, Thailand"),
        ("phuket", "Phuket, Thailand"),
        ("pattaya", "Pattaya, Thailand"),
        ("ho chi minh city", "Ho Chi Minh City, Vietnam"),
        ("hanoi", "Hanoi, Vietnam"),
        ("da nang", "Da Nang, Vietnam"),
        ("phnom penh", "Phnom Penh, Cambodia"),
        ("siem reap", "Siem Reap, Cambodia"),
        ("vientiane", "Vientiane, Laos"),
        ("luang prabang", "Luang Prabang, Laos"),
        ("kuala lumpur", "Kuala Lumpur, Malaysia"),
        ("penang", "Penang, Malaysia"),
        ("malacca", "Malacca, Malaysia"),
        ("jakarta", "Jakarta, Indonesia"),
        ("surabaya", "Surabaya, Indonesia"),
        ("bandung", "Bandung, Indonesia"),
        ("yogyakarta", "Yogyakarta, Indonesia"),
        ("bali", "Bali, Indonesia"),
        ("denpasar", "Denpasar, Indonesia"),
        ("manila", "Manila, Philippines"),
        ("cebu", "Cebu, Philippines"),
        ("davao", "Davao, Philippines"),
        ("macau", "Macau"),
        ("taipei", "Taipei, Taiwan"),
        ("kaohsiung", "Kaohsiung, Taiwan"),
        ("taichung", "Taichung, Taiwan"),
        ("tainan", "Tainan, Taiwan"),
        ("osaka", "Osaka, Japan"),
        ("kyoto", "Kyoto, Japan"),
        ("yokohama", "Yokohama, Japan"),
        ("nagoya", "Nagoya, Japan"),
        ("sapporo", "Sapporo, Japan"),
        ("kobe", "Kobe, Japan"),
        ("fukuoka", "Fukuoka, Japan"),
        ("kawasaki", "Kawasaki, Japan"),
        ("saitama", "Saitama, Japan"),
        ("hiroshima", "Hiroshima, Japan"),
        ("sendai", "Sendai, Japan"),
        ("chiba", "Chiba, Japan"),
        ("kitakyushu", "Kitakyushu, Japan"),
        ("sakai", "Sakai, Japan"),
        ("niigata", "Niigata, Japan"),
        ("hamamatsu", "Hamamatsu, Japan"),
        ("kumamoto", "Kumamoto, Japan"),
        ("sagamihara", "Sagamihara, Japan"),
        ("shizuoka", "Shizuoka, Japan"),
        ("okayama", "Okayama, Japan"),
        ("kagoshima", "Kagoshima, Japan"),
        ("funabashi", "Funabashi, Japan"),
        ("hamamatsu", "Hamamatsu, Japan"),
        ("higashiosaka", "Higashiosaka, Japan"),
        ("hachioji", "Hachioji, Japan"),
        ("nishinomiya", "Nishinomiya, Japan"),
        ("matsuyama", "Matsuyama, Japan"),
        ("urawa", "Urawa, Japan"),
        ("matsudo", "Matsudo, Japan"),
        ("kanazawa", "Kanazawa, Japan"),
        ("kashiwa", "Kashiwa, Japan"),
        ("katsushika", "Katsushika, Japan"),
        ("ota", "Ota, Japan"),
        ("yokosuka", "Yokosuka, Japan"),
        ("nara", "Nara, Japan"),
        ("nagasaki", "Nagasaki, Japan"),
        ("gifu", "Gifu, Japan"),
        ("amagasaki", "Amagasaki, Japan"),
        ("toyonaka", "Toyonaka, Japan"),
        ("toyohashi", "Toyohashi, Japan"),
        ("toyota", "Toyota, Japan"),
        ("takamatsu", "Takamatsu, Japan"),
        ("himeji", "Himeji, Japan"),
        ("okazaki", "Okazaki, Japan"),
        ("kawaguchi", "Kawaguchi, Japan"),
        ("yokkaichi", "Yokkaichi, Japan"),
        ("akita", "Akita, Japan"),
        ("kurashiki", "Kurashiki, Japan"),
        ("otsu", "Otsu, Japan"),
        ("naha", "Naha, Japan"),
        ("aomori", "Aomori, Japan"),
        ("hakodate", "Hakodate, Japan"),
        ("matsue", "Matsue, Japan"),
        ("yamagata", "Yamagata, Japan"),
        ("fukushima", "Fukushima, Japan"),
        ("iwaki", "Iwaki, Japan"),
        ("koriyama", "Koriyama, Japan"),
        ("akashi", "Akashi, Japan"),
        ("tokushima", "Tokushima, Japan"),
        ("kakogawa", "Kakogawa, Japan"),
        ("tokorozawa", "Tokorozawa, Japan"),
        ("sakura", "Sakura, Japan"),
        ("new delhi", "New Delhi, India"),
        ("bangalore", "Bangalore, India"),
        ("hyderabad", "Hyderabad, India"),
        ("ahmedabad", "Ahmedabad, India"),
        ("chennai", "Chennai, India"),
        ("kolkata", "Kolkata, India"),
        ("surat", "Surat, India"),
        ("pune", "Pune, India"),
        ("jaipur", "Jaipur, India"),
        ("lucknow", "Lucknow, India"),
        ("kanpur", "Kanpur, India"),
        ("nagpur", "Nagpur, India"),
        ("indore", "Indore, India"),
        ("thane", "Thane, India"),
        ("bhopal", "Bhopal, India"),
        ("visakhapatnam", "Visakhapatnam, India"),
        ("patna", "Patna, India"),
        ("vadodara", "Vadodara, India"),
        ("ghaziabad", "Ghaziabad, India"),
        ("ludhiana", "Ludhiana, India"),
        ("agra", "Agra, India"),
        ("nashik", "Nashik, India"),
        ("faridabad", "Faridabad, India"),
        ("meerut", "Meerut, India"),
        ("rajkot", "Rajkot, India"),
        ("kalyan", "Kalyan, India"),
        ("vasai", "Vasai, India"),
        ("vashi", "Vashi, India"),
        ("aurangabad", "Aurangabad, India"),
        ("dhanbad", "Dhanbad, India"),
        ("amritsar", "Amritsar, India"),
        ("allahabad", "Allahabad, India"),
        ("ranchi", "Ranchi, India"),
        ("howrah", "Howrah, India"),
        ("coimbatore", "Coimbatore, India"),
        ("jabalpur", "Jabalpur, India"),
        ("gwalior", "Gwalior, India"),
        ("vijayawada", "Vijayawada, India"),
        ("jodhpur", "Jodhpur, India"),
        ("madurai", "Madurai, India"),
        ("raipur", "Raipur, India"),
        ("kota", "Kota, India"),
        ("guwahati", "Guwahati, India"),
        ("chandigarh", "Chandigarh, India"),
        ("solapur", "Solapur, India"),
        ("hubli", "Hubli, India"),
        ("bareilly", "Bareilly, India"),
        ("moradabad", "Moradabad, India"),
        ("mysore", "Mysore, India"),
        ("gurgaon", "Gurgaon, India"),
        ("aligarh", "Aligarh, India"),
        ("jalandhar", "Jalandhar, India"),
        ("tiruchirappalli", "Tiruchirappalli, India"),
        ("bhubaneswar", "Bhubaneswar, India"),
        ("salem", "Salem, India"),
        ("warangal", "Warangal, India"),
        ("guntur", "Guntur, India"),
        ("bhiwandi", "Bhiwandi, India"),
        ("saharanpur", "Saharanpur, India"),
        ("gorakhpur", "Gorakhpur, India"),
        ("bikaner", "Bikaner, India"),
        ("amravati", "Amravati, India"),
        ("noida", "Noida, India"),
        ("jamshedpur", "Jamshedpur, India"),
        ("bhilai", "Bhilai, India"),
        ("cuttack", "Cuttack, India"),
        ("firozabad", "Firozabad, India"),
        ("kochi", "Kochi, India"),
        ("nellore", "Nellore, India"),
        ("bhavnagar", "Bhavnagar, India"),
        ("dehradun", "Dehradun, India"),
        ("durgapur", "Durgapur, India"),
        ("asansol", "Asansol, India"),
        ("rourkela", "Rourkela, India"),
        ("nanded", "Nanded, India"),
        ("kolhapur", "Kolhapur, India"),
        ("ajmer", "Ajmer, India"),
        ("akola", "Akola, India"),
        ("gulbarga", "Gulbarga, India"),
        ("jamnagar", "Jamnagar, India"),
        ("udaipur", "Udaipur, India"),
        ("maheshtala", "Maheshtala, India"),
        ("davanagere", "Davanagere, India"),
        ("kozhikode", "Kozhikode, India"),
        ("kurnool", "Kurnool, India"),
        ("rajahmundry", "Rajahmundry, India"),
        ("bellary", "Bellary, India"),
        ("patiala", "Patiala, India"),
        ("gaya", "Gaya, India"),
        ("parbhani", "Parbhani, India"),
        ("ahmadnagar", "Ahmadnagar, India"),
        ("bharatpur", "Bharatpur, India"),
        ("gandhinagar", "Gandhinagar, India"),
        ("baranagar", "Baranagar, India"),
        ("tiruppur", "Tiruppur, India"),
        ("rohtak", "Rohtak, India"),
        ("korba", "Korba, India"),
        ("bhilwara", "Bhilwara, India"),
        ("berhampur", "Berhampur, India"),
        ("muzaffarnagar", "Muzaffarnagar, India"),
        ("ahmednagar", "Ahmednagar, India"),
        ("mathura", "Mathura, India"),
        ("kollam", "Kollam, India"),
        ("avadi", "Avadi, India"),
        ("kadapa", "Kadapa, India"),
        ("anantapur", "Anantapur, India"),
        ("tirunelveli", "Tirunelveli, India"),
        ("bhatpara", "Bhatpara, India"),
        ("purnia", "Purnia, India"),
        ("satna", "Satna, India"),
        ("mau", "Mau, India"),
        ("baripada", "Baripada, India"),
        ("ratlam", "Ratlam, India"),
        ("hospet", "Hospet, India"),
        ("sasaram", "Sasaram, India"),
        ("hindupur", "Hindupur, India"),
        ("shahjahanpur", "Shahjahanpur, India"),
        ("qutubullapur", "Qutubullapur, India"),
        ("cochin", "Kochi, India"),
        ("calcutta", "Kolkata, India"),
        ("bombay", "Mumbai, India"),
        ("madras", "Chennai, India"),

        // --- Germany (subset kept; you can keep the full list) ---
        ("berlin", "Berlin, Germany"),
        ("munich", "Munich, Germany"),
        ("hamburg", "Hamburg, Germany"),
        ("frankfurt", "Frankfurt, Germany"),
        ("cologne", "Cologne, Germany"),
        ("stuttgart", "Stuttgart, Germany"),
        ("düsseldorf", "Düsseldorf, Germany"),
        ("leipzig", "Leipzig, Germany"),
        ("dresden", "Dresden, Germany"),
        ("bremen", "Bremen, Germany"),
        ("hannover", "Hannover, Germany"),
        ("nuremberg", "Nuremberg, Germany"),
        ("lübeck", "Lübeck, Germany"),
        // ...keep the rest as needed...

        // --- Countries (note: avoid duplicate keys like "djibouti") ---
        ("ethiopia", "Ethiopia"),
        ("kenya", "Kenya"),
        ("nigeria", "Nigeria"),
        ("egypt", "Egypt"),
        ("morocco", "Morocco"),
        ("south africa", "South Africa"),
        ("tanzania", "Tanzania"),
        ("ghana", "Ghana"),
        ("congo", "Democratic Republic of the Congo"),
        ("angola", "Angola"),
        ("tunisia", "Tunisia"),
        ("algeria", "Algeria"),
        ("libya", "Libya"),
        ("sudan", "Sudan"),
        ("south sudan", "South Sudan"),
        // ("djibouti", "Djibouti"),  // ← would duplicate the city key; omit or rename to "djibouti (country)"
        ("somalia", "Somalia"),
        ("eritrea", "Eritrea"),
        ("burundi", "Burundi"),
        ("rwanda", "Rwanda"),
        ("uganda", "Uganda"),
        
        // --- Major World Countries ---
        ("brazil", "Brazil"),
        ("usa", "United States"),
        ("united states", "United States"),
        ("america", "United States"),
        ("uk", "United Kingdom"),
        ("united kingdom", "United Kingdom"),
        ("england", "England, UK"),
        ("france", "France"),
        ("germany", "Germany"),
        ("spain", "Spain"),
        ("italy", "Italy"),
        ("portugal", "Portugal"),
        ("netherlands", "Netherlands"),
        ("belgium", "Belgium"),
        ("switzerland", "Switzerland"),
        ("austria", "Austria"),
        ("sweden", "Sweden"),
        ("norway", "Norway"),
        ("denmark", "Denmark"),
        ("finland", "Finland"),
        ("poland", "Poland"),
        ("czech republic", "Czech Republic"),
        ("czech", "Czech Republic"),
        ("hungary", "Hungary"),
        ("romania", "Romania"),
        ("bulgaria", "Bulgaria"),
        ("greece", "Greece"),
        ("turkey", "Turkey"),
        ("russia", "Russia"),
        ("ukraine", "Ukraine"),
        ("belarus", "Belarus"),
        ("lithuania", "Lithuania"),
        ("latvia", "Latvia"),
        ("estonia", "Estonia"),
        ("japan", "Japan"),
        ("china", "China"),
        ("india", "India"),
        ("pakistan", "Pakistan"),
        ("bangladesh", "Bangladesh"),
        ("sri lanka", "Sri Lanka"),
        ("nepal", "Nepal"),
        ("bhutan", "Bhutan"),
        ("myanmar", "Myanmar"),
        ("thailand", "Thailand"),
        ("vietnam", "Vietnam"),
        ("cambodia", "Cambodia"),
        ("laos", "Laos"),
        ("malaysia", "Malaysia"),
        ("singapore", "Singapore"),
        ("indonesia", "Indonesia"),
        ("philippines", "Philippines"),
        ("australia", "Australia"),
        ("new zealand", "New Zealand"),
        ("canada", "Canada"),
        ("mexico", "Mexico"),
        ("argentina", "Argentina"),
        ("chile", "Chile"),
        ("peru", "Peru"),
        ("colombia", "Colombia"),
        ("venezuela", "Venezuela"),
        ("ecuador", "Ecuador"),
        ("bolivia", "Bolivia"),
        ("paraguay", "Paraguay"),
        ("uruguay", "Uruguay"),
        ("guyana", "Guyana"),
        ("suriname", "Suriname"),
        ("french guiana", "French Guiana"),
        ("south korea", "South Korea"),
        ("north korea", "North Korea"),
        ("mongolia", "Mongolia"),
        ("kazakhstan", "Kazakhstan"),
        ("uzbekistan", "Uzbekistan"),
        ("kyrgyzstan", "Kyrgyzstan"),
        ("tajikistan", "Tajikistan"),
        ("turkmenistan", "Turkmenistan"),
        ("afghanistan", "Afghanistan"),
        ("iran", "Iran"),
        ("iraq", "Iraq"),
        ("syria", "Syria"),
        ("lebanon", "Lebanon"),
        ("jordan", "Jordan"),
        ("israel", "Israel"),
        ("palestine", "Palestine"),
        ("saudi arabia", "Saudi Arabia"),
        ("yemen", "Yemen"),
        ("oman", "Oman"),
        ("uae", "United Arab Emirates"),
        ("united arab emirates", "United Arab Emirates"),
        ("qatar", "Qatar"),
        ("kuwait", "Kuwait"),
        ("bahrain", "Bahrain"),
        ("cyprus", "Cyprus"),
        ("malta", "Malta"),
        ("iceland", "Iceland"),
        ("ireland", "Ireland"),
        ("scotland", "Scotland, UK"),
        ("wales", "Wales, UK"),
        ("northern ireland", "Northern Ireland, UK")
    ]

    // Build a dictionary once, skipping duplicates (case-insensitive)
    private lazy var fallbackPlaces: [String: String] = {
        var dict: [String: String] = [:]
        for (rawKey, value) in fallbackPlacesPairs {
            let key = rawKey.lowercased()
            if dict[key] == nil { dict[key] = value } // first occurrence wins
        }
        return dict
    }()
     
     private func getFallbackResults(for query: String) -> [PlacePrediction] {
         let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
         
         // Find exact matches first
         var exactMatches: [PlacePrediction] = []
         var partialMatches: [PlacePrediction] = []
         
         for (key, value) in fallbackPlaces {
             if key == queryLower {
                 // Exact match - add to top
                 exactMatches.append(PlacePrediction(
                     placeId: "fallback_\(key)",
                     description: value
                 ))
             } else if key.contains(queryLower) || queryLower.contains(key) {
                 // Partial match
                 partialMatches.append(PlacePrediction(
                     placeId: "fallback_\(key)",
                     description: value
                 ))
             }
         }
         
         // Combine results with exact matches first
         let results = exactMatches + partialMatches
         
         // Limit to top 10 results
         return Array(results.prefix(10))
     }
     
     private func tryAlternativeSearch(query: String) async {
         let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Strategy 2: Try with different parameters
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "input", value: encodedQuery),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "types", value: "geocode"), // Try geocode type
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "sessiontoken", value: UUID().uuidString)
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
                    print("🔍 Alternative search returned \(placesResponse.predictions.count) predictions")
                    
                    let relevantPredictions = placesResponse.predictions.filter { prediction in
                        let description = prediction.description.lowercased()
                        let mainText = prediction.structuredFormatting.mainText.lowercased()
                        let query = query.lowercased()
                        
                        let isRelevant = mainText.hasPrefix(query) || 
                                        mainText.contains(query) ||
                                        description.contains(query)
                        
                        return isRelevant
                    }
                    
                    var apiPredictions = relevantPredictions.map { prediction in
                        PlacePrediction(
                            placeId: prediction.placeId,
                            description: prediction.description
                        )
                    }
                    
                    // Add fallback results
                    let fallbackResults = self.getFallbackResults(for: query)
                    apiPredictions.append(contentsOf: fallbackResults)
                    
                    self.predictions = apiPredictions
                } else {
                    // Use only fallback results
                    let fallbackResults = self.getFallbackResults(for: query)
                    if fallbackResults.isEmpty {
                        self.errorMessage = "No results found"
                    }
                    self.predictions = fallbackResults
                }
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                // Use fallback results on error
                let fallbackResults = self.getFallbackResults(for: query)
                if fallbackResults.isEmpty {
                    self.errorMessage = "Failed to fetch suggestions"
                }
                self.predictions = fallbackResults
                self.isLoading = false
            }
        }
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
                                selectedLocation = prediction.description
                                searchText = prediction.description
                                onLocationSelected(prediction.description)
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
