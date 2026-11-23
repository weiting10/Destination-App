//
//  PostcardGalleryView.swift
//  Destinations
//
//  "My Postcards": every postcard sent, newest first. Each card sits on top of its
//  own back like a little stack, tilted slightly, and cards tip and shrink as they
//  scroll in and out. Tap a card to open it; long-press to delete.
//

import SwiftUI
import SwiftData

struct PostcardGalleryView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Postcard.dateSent, order: .reverse) private var postcards: [Postcard]

    var body: some View {
        Group {
            if postcards.isEmpty {
                ContentUnavailableView {
                    Label("No postcards yet", systemImage: "envelope.open")
                } description: {
                    Text("Open a place in Places I've been and tap Send a postcard.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 36) {
                        ForEach(Array(postcards.enumerated()), id: \.element.id) { index, postcard in
                            NavigationLink {
                                PostcardDetailView(postcard: postcard)
                            } label: {
                                GalleryCard(postcard: postcard, tilt: index.isMultiple(of: 2) ? -2 : 2)
                            }
                            .buttonStyle(.plain)
                            .scrollTransition(.interactive) { card, phase in
                                card
                                    .scaleEffect(phase.isIdentity ? 1 : 0.86)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                                    .rotation3DEffect(.degrees(phase.value * 22), axis: (x: 1, y: 0, z: 0))
                            }
                            .contextMenu {
                                Button("Delete postcard", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(postcard)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background_color").ignoresSafeArea())
        .navigationTitle("My Postcards")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GalleryCard: View {
    let postcard: Postcard
    let tilt: Double

    var body: some View {
        let content = postcard.content

        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                PostcardBackView(content: content)
                    .rotationEffect(.degrees(-tilt * 2))
                    .offset(x: 6, y: 10)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                PostcardFrontView(content: content)
                    .rotationEffect(.degrees(tilt))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(content.placeName)
                    .font(.headline)
                Spacer()
                Text(content.date, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            if let firstLine = content.address.components(separatedBy: .newlines).first, !firstLine.isEmpty {
                Text("To: \(firstLine)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        PostcardGalleryView()
    }
    .modelContainer(for: Postcard.self, inMemory: true)
    .accentTint()
}
