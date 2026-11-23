//
//  DataReset.swift
//  Destinations
//
//  "Forgot your PIN?" → erase everything the user entered: places, photos and postcards.
//

import SwiftData

enum DataReset {

    @MainActor
    static func eraseAll(in context: ModelContext) {
        do {
            // Deleting each place also deletes its photos (cascade rule);
            // the second pass catches any photo that lost its place.
            for place in try context.fetch(FetchDescriptor<VisitedPlace>()) {
                context.delete(place)
            }
            for photo in try context.fetch(FetchDescriptor<PlacePhoto>()) {
                context.delete(photo)
            }
            for postcard in try context.fetch(FetchDescriptor<Postcard>()) {
                context.delete(postcard)
            }
            try context.save()
        } catch {
            print("Could not erase data: \(error)")
        }
    }
}
