//
//  VisitedPlacesView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//
//This file lists the places you’ve been, each with its visit date and photo count. The + button opens a sheet to add a place (typed, or filled in from your current location), and swiping a row deletes it.


import SwiftUI
import SwiftData

struct VisitedPlacesView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VisitedPlace.dateAdded) private var places: [VisitedPlace]

    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {

            Text("Places I've Been")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 8)

            if places.isEmpty {
                Spacer()
                Text("No places yet.\nTap + to add your first one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(places) { place in
                        NavigationLink {
                            DiaryView(place: place)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(place.name).font(.headline)
                                    Spacer()
                                    Text((place.visitDate ?? place.dateAdded)
                                        .formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(place.photos.count) photo(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background_color").ignoresSafeArea())
        .tint(Color("arrow_color"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPlaceSheet { name in
                addPlace(named: name)
            }
            .presentationDetents([.medium])
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addPlace(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(VisitedPlace(name: trimmed))
        try? modelContext.save()
    }

    // The cascade delete rule removes each place's photos as well.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(places[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        VisitedPlacesView()
    }
    .modelContainer(for: VisitedPlace.self, inMemory: true)
}
