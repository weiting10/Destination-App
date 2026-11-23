//
//  InfoView.swift
//  Destinations
//
//  About the app: the icon (exported from the Icon Composer document into the
//  "AppIconImage" image set), version, credits and the localized privacy policy,
//  which opens as a full-screen cover.
//

import SwiftUI

struct InfoView: View {

    @State private var showingPrivacyPolicy = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {

                // Light and dark exports live in the same image set, so this switches by itself.
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                    .padding(.top, 20)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text("My Little Travel Journal")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Keep the places you've been, your photos and notes, and send postcards from your trips.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 14) {
                    infoRow("person.fill", "Made by Weiting Tan")
                    infoRow("iphone", "Everything you enter stays on this device.")
                    infoRow("globe", "Available in English and Arabic.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                Button {
                    showingPrivacyPolicy = true
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                if let url = URL(string: "https://github.com/weiting10/Destination-App") {
                    Link(destination: url) {
                        Label("Project on GitHub", systemImage: "link")
                    }
                }

                Text("© 2026 Weiting Tan. All rights reserved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Color("background_color").ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
                .accentTint()
        }
    }

    private func infoRow(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        InfoView()
    }
    .accentTint()
}
