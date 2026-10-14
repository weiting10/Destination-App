//
//  VisitedPlacesView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//
//This file lists the places you’ve been, each with its visit date and photo count. The + button adds a place, and swiping a row deletes it.


import SwiftUI

struct VisitedPlacesView: View {

    @Environment(VisitedStore.self) private var store
    @State private var showingAddAlert = false
    @State private var newPlaceName = ""

    var body: some View {
        VStack(spacing: 0) {

            Text("Places I've Been")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 8)

            if store.places.isEmpty {
                Spacer()
                Text("No places yet.\nTap + to add your first one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(store.places) { place in
                        NavigationLink {
                            DiaryView(placeID: place.id)
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
                                Text("\(place.photoFilenames.count) photo(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.delete(at: $0) }
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
                    newPlaceName = ""
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add a place", isPresented: $showingAddAlert) {
            TextField("e.g. Kyoto", text: $newPlaceName)
            Button("Add") { store.add(name: newPlaceName) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Where have you been?")
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VisitedPlacesView()
    }
    .environment(VisitedStore())
}
