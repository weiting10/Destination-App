//
//  VisitedPlace.swift
//  Destinations
//
// SwiftData models for everything the user enters: places, visit dates, notes and photos.
// These replace VisitedStore.swift (delete that file from the project).

import SwiftUI
import SwiftData

@Model
final class VisitedPlace {
    var name: String
    var dateAdded: Date
    /// The date the user visited. Optional so a place can exist before a date is chosen.
    var visitDate: Date?
    var notes: String

    /// Deleting a place also deletes its photos.
    @Relationship(deleteRule: .cascade, inverse: \PlacePhoto.place)
    var photos: [PlacePhoto] = []

    init(name: String, dateAdded: Date = .now, visitDate: Date? = nil, notes: String = "") {
        self.name = name
        self.dateAdded = dateAdded
        self.visitDate = visitDate
        self.notes = notes
    }

    /// Photos in the order they were added (SwiftData relationships are unordered).
    var sortedPhotos: [PlacePhoto] {
        photos.sorted { $0.dateAdded < $1.dateAdded }
    }
}

@Model
final class PlacePhoto {
    /// Large binary data is kept outside the main database file.
    @Attribute(.externalStorage) var imageData: Data
    var dateAdded: Date
    var place: VisitedPlace?

    init(imageData: Data, dateAdded: Date = .now) {
        self.imageData = imageData
        self.dateAdded = dateAdded
    }
}
