//
//  PostcardComposerView.swift
//  Destinations
//
//  "Send a postcard" from a diary page: pick one of the place's photos, write the
//  address, your name and a message, and watch the card update as you type.
//  Send saves it to My Postcards, then opens the share sheet with the finished postcard
//  (front and back as one PNG). When the share sheet closes, the card flies away.
//

import SwiftUI
import SwiftData

struct PostcardComposerView: View {

    let place: VisitedPlace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage(SettingsKey.accentColorHex) private var accentHex = ""

    @State private var selectedPhotoID: PersistentIdentifier?
    @State private var address = ""
    @State private var sender = ""          // starts blank every time
    @State private var message: String
    @State private var showsBack = false
    @State private var sending = false
    @State private var flownAway = false

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
                        .offset(y: flownAway ? -700 : 0)
                        .rotationEffect(.degrees(flownAway ? -12 : 0))
                        .opacity(flownAway ? 0 : 1)

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

        sending = true    // disables Send so it can't be tapped twice

        // Render the postcard to a PNG and open the share sheet.
        // Whether the user shares or cancels, the postcard is already saved in My Postcards.
        if let url = PostcardExporter.pngFile(for: postcard.content,
                                              tint: Theme.accent(fromHex: accentHex),
                                              locale: locale,
                                              layoutDirection: layoutDirection) {
            ShareSheet.present(items: [url]) {
                flyAwayAndClose()
            }
        } else {
            flyAwayAndClose()
        }
    }

    /// The card flies off the screen, then the sheet closes.
    private func flyAwayAndClose() {
        withAnimation(.easeIn(duration: 0.55)) { flownAway = true }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        }
    }
}

// MARK: - Share sheet

/// Opens the system share sheet (UIActivityViewController) on top of whatever is showing.
/// SwiftUI's ShareLink only opens when the user taps it, so this is used to open it
/// right after Send. `onFinish` runs once the share sheet closes (shared or cancelled).
@MainActor
enum ShareSheet {

    static func present(items: [Any], onFinish: @escaping () -> Void) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            onFinish()
            return
        }

        // Present from the top-most screen (here: the composer sheet).
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onFinish() }
        }
        // iPad shows the share sheet as a popover, which needs an anchor.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(controller, animated: true)
    }
}
