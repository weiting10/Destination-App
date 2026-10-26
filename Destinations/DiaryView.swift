//
//  DiaryView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//
// This is the diary page for one place. It has the date picker, the notes box, and the photo grid, and “Add photos” opens the photo picker. Tapping a photo opens the viewer.

import SwiftUI
import SwiftData
import PhotosUI

struct DiaryView: View {

    /// The SwiftData object itself. Edits to it are saved automatically.
    @Bindable var place: VisitedPlace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedPhoto: PlacePhoto?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    /// visitDate is optional, so fall back to the date the place was added.
    private var visitDateBinding: Binding<Date> {
        Binding(
            get: { place.visitDate ?? place.dateAdded },
            set: {
                place.visitDate = $0
                save()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Travel Diary")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(place.name)
                    .font(.system(size: 34, weight: .bold))

                DatePicker("Date visited",
                           selection: visitDateBinding,
                           in: ...Date(),
                           displayedComponents: .date)
                    .font(.headline)

                Text("Your notes")
                    .font(.headline)

                TextEditor(text: $place.notes)
                    .frame(minHeight: 180)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: place.notes) { save() }

                HStack {
                    Text("Photos").font(.headline)
                    Spacer()
                    PhotosPicker(selection: $pickerItems, matching: .images) {
                        Label("Add photos", systemImage: "photo.badge.plus")
                    }
                }

                if place.photos.isEmpty {
                    Text("No photos yet.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(place.sortedPhotos) { photo in
                            if let image = UIImage(data: photo.imageData) {
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
                                        selectedPhoto = photo
                                    }
                                    .contextMenu {
                                        Button("Delete photo", role: .destructive) {
                                            modelContext.delete(photo)
                                            save()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color("background_color").ignoresSafeArea())
        .tint(Color("arrow_color"))
        .onChange(of: pickerItems) { _, items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpeg = image.jpegData(compressionQuality: 0.8) {
                        place.photos.append(PlacePhoto(imageData: jpeg))
                    }
                }
                save()
                pickerItems = []
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoViewerView(image: UIImage(data: photo.imageData) ?? UIImage()) {
                selectedPhoto = nil
                modelContext.delete(photo)
                save()
            }
        }
        // Safety nets: write to disk when leaving the page or when the app leaves the foreground.
        .onDisappear { save() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { save() }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Write pending changes to disk right away instead of waiting for SwiftData's autosave.
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Could not save: \(error)")
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: VisitedPlace.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let place = VisitedPlace(name: "Kyoto")
    container.mainContext.insert(place)
    return NavigationStack {
        DiaryView(place: place)
    }
    .modelContainer(container)
}
