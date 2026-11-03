//
//  AddPlaceSheet.swift
//  Destinations
//
//  The "Add a place" sheet: type a place name, or tap the location button to fill it in
//  from where you are right now. The user can still edit the name before adding.
//

import SwiftUI
import CoreLocationUI

struct AddPlaceSheet: View {

    @Environment(\.dismiss) private var dismiss

    /// Called with the trimmed, non-empty name when the user taps Add.
    let onAdd: (String) -> Void

    @State private var name = ""
    @State private var finder = CurrentPlaceFinder()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                Text("Where have you been?")
                    .font(.headline)

                TextField("e.g. Kyoto", text: $name)
                    .textFieldStyle(.roundedBorder)

                LocationButton(.currentLocation) {
                    finder.findCurrentPlace()
                }
                .symbolVariant(.fill)
                .labelStyle(.titleAndIcon)
                .cornerRadius(10)

                statusView

                Text("Your location is used once, only to fill in the place name. It is not saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(Color("background_color").ignoresSafeArea())
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(trimmedName)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onChange(of: finder.state) { _, newState in
                if case .found(let placeName) = newState {
                    name = placeName
                }
            }
        }
        .tint(Color("arrow_color"))
    }

    @ViewBuilder
    private var statusView: some View {
        switch finder.state {
        case .idle:
            EmptyView()
        case .locating:
            HStack(spacing: 8) {
                ProgressView()
                Text("Finding where you are…")
                    .foregroundStyle(.secondary)
            }
        case .found(let placeName):
            Text("Found: \(placeName)")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    AddPlaceSheet { _ in }
}
