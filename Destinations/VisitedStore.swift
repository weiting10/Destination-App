//
//  VisitedStore.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//
// This file holds everything you’ve entered: places, visit dates, notes and photos.

import SwiftUI

struct VisitedPlace: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var dateAdded = Date()
    /// The date the user visited. Optional so places saved before this field existed still load.
    var visitDate: Date? = nil
    var notes = ""
    var photoFilenames: [String] = []
}

@Observable
class VisitedStore {

    private(set) var places: [VisitedPlace] = []

    private let fileURL = URL.documentsDirectory.appending(path: "visited_places.json")

    init() {
        load()
    }

    // MARK: - Places

    func place(id: UUID) -> VisitedPlace? {
        places.first { $0.id == id }
    }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        places.append(VisitedPlace(name: trimmed))
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            for filename in places[index].photoFilenames {
                try? FileManager.default.removeItem(at: photoURL(filename))
            }
        }
        places.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Diary

    func updateVisitDate(_ date: Date, for id: UUID) {
        guard let i = places.firstIndex(where: { $0.id == id }) else { return }
        places[i].visitDate = date
        save()
    }

    func updateNotes(_ notes: String, for id: UUID) {
        guard let i = places.firstIndex(where: { $0.id == id }) else { return }
        places[i].notes = notes
        save()
    }

    func addPhoto(_ data: Data, to id: UUID) {
        guard let i = places.firstIndex(where: { $0.id == id }),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: photoURL(filename))
            places[i].photoFilenames.append(filename)
            save()
        } catch {
            print("Could not save photo: \(error)")
        }
    }

    func removePhoto(_ filename: String, from id: UUID) {
        guard let i = places.firstIndex(where: { $0.id == id }) else { return }
        places[i].photoFilenames.removeAll { $0 == filename }
        try? FileManager.default.removeItem(at: photoURL(filename))
        save()
    }

    func image(named filename: String) -> UIImage? {
        UIImage(contentsOfFile: photoURL(filename).path)
    }

    // MARK: - Persistence

    private func photoURL(_ filename: String) -> URL {
        URL.documentsDirectory.appending(path: filename)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(places)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Could not save places: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([VisitedPlace].self, from: data) else { return }
        places = decoded
    }
}
