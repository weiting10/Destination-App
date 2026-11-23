//
//  PhotoViewerView.swift
//  Destinations
//
//  Created by Tan, Weiting on 10/14/26.
//

// This shows one photo full screen. Tapping the photo closes it, and the trash button deletes it after a confirmation.

import SwiftUI

struct PhotoViewerView: View {

    let image: UIImage
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            // Tapping the photo or the black background closes the viewer.
            Color.black
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { dismiss() }

            VStack {
                HStack {
                    Text("Photo Viewer")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if onDelete != nil {
                        Button {
                            confirmingDelete = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                Text("Tap photo to close")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 16)
            }
        }
        .confirmationDialog("Delete this photo?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete photo", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }
}

#Preview {
    PhotoViewerView(image: UIImage(systemName: "photo")!, onDelete: {})
}
