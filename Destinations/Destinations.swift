//
//  Destinations.swift
//
//  Created by Tan, Weiting on 10/14/26.
//
//  The seven destinations. Names and descriptions are localized (Localizable.xcstrings);
//  descriptions use short keys so the long English text isn't the lookup key.
//

import SwiftUI

@Observable
class Destinations {

    public var index = 0

    public let destinations: [String] = [
        String(localized: "China"),
        String(localized: "Japan"),
        String(localized: "Korea"),
        String(localized: "France"),
        String(localized: "California"),
        String(localized: "Singapore"),
        String(localized: "Toronto")
    ]

    private let images = ["china_image", "japan_image", "korea_image_6", "france_image",
                          "california_image", "singapore_image", "toronto_image_3"]

    private let destination_descriptions: [String] = [
        String(localized: "destination.china.description",
               defaultValue: "China blends thousands of years of history with fast-paced modern cities. Visit the Great Wall and the Forbidden City in Beijing, see the Terracotta Army in Xi'an, or explore the futuristic skyline of Shanghai. The country is also known for its diverse regional cuisines and stunning landscapes like Guilin and Zhangjiajie."),

        String(localized: "destination.japan.description",
               defaultValue: "Japan is a fascinating mix of ancient tradition and cutting-edge technology. Visit peaceful temples and cherry blossoms in Kyoto, experience the neon-lit energy of Tokyo, and ride the high-speed bullet train between cities. Japanese food, from fresh sushi to steaming ramen, is a highlight of any trip."),

        String(localized: "destination.korea.description",
               defaultValue: "South Korea combines historic palaces and mountain temples with a vibrant modern culture known for K-pop, fashion, and technology. Seoul is filled with lively markets, street food, and nightlife, while Jeju Island offers beautiful volcanic scenery and beaches. Korean barbecue and kimchi are must-try dishes."),

        String(localized: "destination.france.description",
               defaultValue: "France is famous for its art, fashion, and world-class food and wine. Paris draws visitors with the Eiffel Tower, the Louvre, and charming cafés, while the countryside offers lavender fields in Provence and glamorous beaches on the French Riviera. Historic castles and villages make it a dream for culture lovers."),

        String(localized: "destination.california.description",
               defaultValue: "California offers sunny beaches, mountains, deserts, and vibrant cities all in one state. Drive along the Pacific Coast Highway, explore San Francisco's Golden Gate Bridge, or visit Hollywood and Disneyland in the Los Angeles area. Nature lovers can also enjoy national parks like Yosemite and Joshua Tree."),

        String(localized: "destination.singapore.description",
               defaultValue: "Singapore is a clean, modern city-state known for its impressive skyline and lush green spaces. Highlights include the Gardens by the Bay, the Marina Bay Sands hotel, and the famous hawker centers where you can enjoy affordable, delicious food. Its mix of Chinese, Malay, Indian, and Western cultures makes it especially unique."),

        String(localized: "destination.toronto.description",
               defaultValue: "Toronto is Canada's largest city and one of the most multicultural places in the world. Visitors can go up the CN Tower for skyline views, explore diverse neighborhoods like Kensington Market, and take a short trip to nearby Niagara Falls. The city also has a great food scene, museums, and a lively waterfront.")
    ]

    func current() -> (destination: String, description: String, image: String) {
        (destinations[index], destination_descriptions[index], images[index])
    }

    /// Jump to a random destination.
    func randomize() {
        index = Int.random(in: 0..<destinations.count)
    }

    func next() {
        index = (index + 1) % destinations.count
    }

    func previous() {
        index = (index - 1 + destinations.count) % destinations.count
    }
}
