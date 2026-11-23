//
//  PostcardComposerView.swift
//  Destinations
//
//  "Send a postcard" from a diary page: pick one of the place's photos, write the
//  address, your name and a message, and watch the card update as you type.
//  Send saves it to My Postcards (where it can be shared or exported as a PNG).
//

import SwiftUI
import SwiftData

struct PostcardComposerView: View {

    let place: VisitedPlace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoID: PersistentIdentifier?
    @State private var address = ""
    @State private var sender = ""          // starts blank every time
    @State private var message: String
    @State private var showsBack = false
    @State private var sending = false

    init(place: VisitedPlace) {
        self.place = place
        _message = State(initialValue: String(localized: "Greetings from \(place.name)!"))
        _selectedPhotoID = State(initialValue: place.sortedPhotos.first?.persistentModelID)
    }

    private var selectedPhoto: PlacePhoto? {
        place.sortedPhotos.first { $0.persistentModelID == selectedPhotoID }
    }

    private var canSend: Bool {
        selectedPhoto != nil
            && !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var preview: PostcardContent {
        PostcardContent(image: selectedPhoto.flatMap { UIImage(data: $0.imageData) } ?? UIImage(),
                        placeName: place.name,
                        message: message,
                        sender: sender,
                        address: address,
                        date: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    // Live preview: tap or use the picker to turn it over.
                    FlippablePostcard(content: preview, showsBack: showsBack)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.6)) { showsBack.toggle() }
                        }
                        .offset(y: sending ? -700 : 0)
                        .rotationEffect(.degrees(sending ? -12 : 0))
                        .opacity(sending ? 0 : 1)

                    Picker("Side", selection: Binding(
                        get: { showsBack },
                        set: { newValue in withAnimation(.spring(duration: 0.6)) { showsBack = newValue } }
                    )) {
                        Text("Photo side").tag(false)
                        Text("Message side").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Text("Photo")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(place.sortedPhotos) { photo in
                                photoChoice(photo)
                            }
                        }
                        .padding(2)
                    }

                    Text("Address")
                        .font(.headline)
                    TextField("Name, street, city, country", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                        .textContentType(.fullStreetAddress)
                        .padding(10)
                        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    Text("From")
                        .font(.headline)
                    TextField("Your name", text: $sender)
                        .textContentType(.name)
                        .padding(10)
                        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    Text("Message")
                        .font(.headline)
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color("background_color").ignoresSafeArea())
            .navigationTitle("New postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(!canSend || sending)
                }
            }
        }
    }

    private func photoChoice(_ photo: PlacePhoto) -> some View {
        let isSelected = photo.persistentModelID == selectedPhotoID
        return Button {
            selectedPhotoID = photo.persistentModelID
        } label: {
            Color.clear
                .frame(width: 78, height: 78)
                .overlay {
                    if let image = UIImage(data: photo.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.tint, lineWidth: isSelected ? 4 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .tint)
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func send() {
        guard let photo = selectedPhoto else { return }
        let postcard = Postcard(imageData: photo.imageData,
                                placeName: place.name,
                                address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                                sender: sender.trimmingCharacters(in: .whitespacesAndNewlines),
                                message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(postcard)
        do {
            try modelContext.save()
        } catch {
            print("Could not save the postcard: \(error)")
        }

        // The card flies away, then the sheet closes.
        withAnimation(.easeIn(duration: 0.55)) { sending = true }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        }
    }
}
