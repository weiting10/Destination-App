//
//  DiaryView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//
// This is the diary page for one place. It has the date picker, the notes box, and the photo grid, and “Add photos” opens the photo picker. Tapping a photo opens the viewer.

import SwiftUI
import PhotosUI

struct DiaryView: View {

    let placeID: UUID

    @Environment(VisitedStore.self) private var store
    @State private var notes = ""
    @State private var pickerItems: [PhotosPickerItem] = []

    @State private var visitDate = Date()
    @State private var selectedFilename: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        ScrollView {
            if let place = store.place(id: placeID) {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Travel Diary")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(place.name)
                        .font(.system(size: 34, weight: .bold))

                    DatePicker("Date visited",
                               selection: $visitDate,
                               in: ...Date(),
                               displayedComponents: .date)
                        .font(.headline)
                        .onChange(of: visitDate) { _, newValue in
                            store.updateVisitDate(newValue, for: placeID)
                        }

                    Text("Your notes")
                        .font(.headline)

                    TextEditor(text: $notes)
                        .frame(minHeight: 180)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: notes) { _, newValue in
                            store.updateNotes(newValue, for: placeID)
                        }

                    HStack {
                        Text("Photos").font(.headline)
                        Spacer()
                        PhotosPicker(selection: $pickerItems, matching: .images) {
                            Label("Add photos", systemImage: "photo.badge.plus")
                        }
                    }

                    if place.photoFilenames.isEmpty {
                        Text("No photos yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(place.photoFilenames, id: \.self) { filename in
                                if let image = store.image(named: filename) {
                                    // Square cell: the image fills it and is clipped to it,
                                    // so neighbouring photos can't overlap.
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        }
                                        .clipped()
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedFilename = filename
                                        }
                                        .contextMenu {
                                            Button("Delete photo", role: .destructive) {
                                                store.removePhoto(filename, from: placeID)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding()
            } else {
                Text("This place no longer exists.")
                    .padding()
            }
        }
        .background(Color("background_color").ignoresSafeArea())
        .tint(Color("arrow_color"))
        .onAppear {
            if let place = store.place(id: placeID) {
                notes = place.notes
                visitDate = place.visitDate ?? place.dateAdded
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.addPhoto(data, to: placeID)
                    }
                }
                pickerItems = []
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedFilename != nil },
            set: { if !$0 { selectedFilename = nil } }
        )) {
            if let filename = selectedFilename,
               let image = store.image(named: filename) {
                PhotoViewerView(image: image) {
                    store.removePhoto(filename, from: placeID)
                    selectedFilename = nil
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let store = VisitedStore()
    store.add(name: "Kyoto")
    return NavigationStack {
        DiaryView(placeID: store.places[0].id)
    }
    .environment(store)
}
