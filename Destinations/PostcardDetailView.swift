//
//  PostcardDetailView.swift
//  Destinations
//
//  One postcard, large. Tap it to turn it over. "Share or export" renders the front
//  and back into one PNG and opens the share sheet (Save to Files, AirDrop, Messages…).
//

import SwiftUI
import SwiftData

struct PostcardDetailView: View {

    let postcard: Postcard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage(SettingsKey.accentColorHex) private var accentHex = ""

    @State private var showsBack = false
    @State private var exportURL: URL?
    @State private var confirmingDelete = false
    @State private var deleted = false

    var body: some View {
        // Once deleted, stop reading the model while the screen closes.
        if deleted {
            Color("background_color").ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let card = postcard.content

        return ScrollView {
            VStack(spacing: 22) {
                FlippablePostcard(content: card, showsBack: showsBack)
                    .padding(.top, 12)
                    .onTapGesture { flip() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(Text("Turns the postcard over"))

                Text(showsBack ? "Tap the card to see the front" : "Tap the card to see the back")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    Button {
                        flip()
                    } label: {
                        Label("Flip", systemImage: "rotate.3d")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let exportURL {
                        ShareLink(item: exportURL,
                                  preview: SharePreview(String(localized: "Postcard from \(card.placeName)"),
                                                        image: Image(uiImage: card.image))) {
                            Label("Share or export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sent \(card.date.formatted(date: .long, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("To")
                        .font(.headline)
                    Text(card.address)
                    Text("From")
                        .font(.headline)
                    Text(card.sender)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color("background_color").ignoresSafeArea())
        .navigationTitle(card.placeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text("Delete postcard"))
            }
        }
        .confirmationDialog("Delete this postcard?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete postcard", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
        .task {
            exportURL = PostcardExporter.pngFile(for: card,
                                                 tint: Theme.accent(fromHex: accentHex),
                                                 locale: locale,
                                                 layoutDirection: layoutDirection)
        }
    }

    private func flip() {
        withAnimation(.spring(duration: 0.6)) { showsBack.toggle() }
    }

    private func delete() {
        deleted = true
        modelContext.delete(postcard)
        try? modelContext.save()
        dismiss()
    }
}
