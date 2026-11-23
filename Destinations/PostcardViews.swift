//
//  PostcardViews.swift
//  Destinations
//
//  How a postcard looks:
//  - Front: the large photo in a paper border with "Greetings from <place>".
//  - Back: the message on one side; stamp, postmark, address and sender on the other.
//  - FlippablePostcard: front and back in one card that turns over in 3D.
//  - PostcardExportView + PostcardExporter: front and back together, rendered to a PNG.
//  Every size is a fraction of the card's width (u = width / 100), so the same card
//  looks right in the gallery, full width, and in the high-resolution export.
//

import SwiftUI

enum PostcardStyle {
    static let aspectRatio: CGFloat = 1.5
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.20, green: 0.17, blue: 0.15)
}

// MARK: - Front

struct PostcardFrontView: View {
    let content: PostcardContent

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / 100
            let inset = 2.5 * u

            ZStack(alignment: .bottomLeading) {
                Image(uiImage: content.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width - 2 * inset, height: geo.size.height - 2 * inset)
                    .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Greetings from")
                        .font(.system(size: 4.2 * u, weight: .semibold, design: .serif))
                        .italic()
                    Text(content.placeName)
                        .font(.system(size: 10 * u, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: u)
                .padding(5 * u)
            }
            .frame(width: geo.size.width - 2 * inset, height: geo.size.height - 2 * inset)
            .clipShape(RoundedRectangle(cornerRadius: 1.5 * u))
            .frame(width: geo.size.width, height: geo.size.height)
            .background(PostcardStyle.paper)
            .clipShape(RoundedRectangle(cornerRadius: 3 * u))
        }
        .aspectRatio(PostcardStyle.aspectRatio, contentMode: .fit)
    }
}

// MARK: - Back

struct PostcardBackView: View {
    let content: PostcardContent

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / 100

            HStack(spacing: 0) {
                // Message side
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text(content.message)
                        .font(.system(size: 4.4 * u, design: .serif))
                        .italic()
                        .lineSpacing(0.8 * u)
                        .minimumScaleFactor(0.45)
                    Spacer(minLength: 0)
                    if !content.sender.isEmpty {
                        Text(verbatim: "— \(content.sender)")
                            .font(.system(size: 4.2 * u, weight: .semibold, design: .serif))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(5 * u)

                Rectangle()
                    .fill(PostcardStyle.ink.opacity(0.25))
                    .frame(width: 0.3 * u)
                    .padding(.vertical, 6 * u)

                // Address side
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Postmark(placeName: content.placeName, date: content.date, u: u)
                        Spacer(minLength: 0)
                        Stamp(u: u)
                    }
                    Spacer(minLength: 2 * u)
                    VStack(alignment: .leading, spacing: 3 * u) {
                        ForEach(Array(addressLines.enumerated()), id: \.offset) { _, line in
                            Text(verbatim: line.isEmpty ? " " : line)
                                .font(.system(size: 3.8 * u, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(PostcardStyle.ink.opacity(0.3))
                                        .frame(height: 0.25 * u)
                                        .offset(y: 1.2 * u)
                                }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(5 * u)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(PostcardStyle.ink)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(PostcardStyle.paper)
            .clipShape(RoundedRectangle(cornerRadius: 3 * u))
        }
        .aspectRatio(PostcardStyle.aspectRatio, contentMode: .fit)
    }

    /// Always four ruled lines; any extra lines are joined onto the last one.
    private var addressLines: [String] {
        var lines = content.address
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count > 4 {
            lines = Array(lines.prefix(3)) + [lines.dropFirst(3).joined(separator: ", ")]
        }
        while lines.count < 4 { lines.append("") }
        return lines
    }
}

private struct Stamp: View {
    let u: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0.6 * u)
                .fill(.tint.opacity(0.85))
            Image(systemName: "airplane")
                .font(.system(size: 6 * u))
                .foregroundStyle(.white)
                .flipsForRightToLeftLayoutDirection(true)
        }
        .frame(width: 13 * u, height: 16 * u)
        .padding(1.2 * u)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 0.6 * u)
                .strokeBorder(style: StrokeStyle(lineWidth: 0.6 * u, dash: [1.1 * u, 0.7 * u]))
                .foregroundStyle(PostcardStyle.ink.opacity(0.35))
        )
        .rotationEffect(.degrees(3))
    }
}

private struct Postmark: View {
    let placeName: String
    let date: Date
    let u: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(lineWidth: 0.5 * u)
            VStack(spacing: 0.4 * u) {
                Text(verbatim: placeName.uppercased())
                    .font(.system(size: 2.4 * u, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 2.8 * u, weight: .semibold, design: .rounded))
                Text(date, format: .dateTime.year())
                    .font(.system(size: 2.4 * u, design: .rounded))
            }
            .padding(2.2 * u)
        }
        .frame(width: 17 * u, height: 17 * u)
        .foregroundStyle(PostcardStyle.ink.opacity(0.55))
        .rotationEffect(.degrees(-12))
    }
}

// MARK: - Flip

/// Front and back in one card. Change `showsBack` inside withAnimation to turn it over.
struct FlippablePostcard: View {
    let content: PostcardContent
    let showsBack: Bool

    var body: some View {
        ZStack {
            PostcardFrontView(content: content)
                .opacity(showsBack ? 0 : 1)
            PostcardBackView(content: content)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(showsBack ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Export

/// Front above back, on a soft background: this is what the PNG looks like.
struct PostcardExportView: View {
    let content: PostcardContent

    var body: some View {
        VStack(spacing: 32) {
            PostcardFrontView(content: content)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
            PostcardBackView(content: content)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
            Label("My Little Travel Journal", systemImage: "airplane.departure")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.tint)
        }
        .padding(44)
        .frame(width: 900)
        .background(
            LinearGradient(colors: [Color(red: 0.93, green: 0.95, blue: 0.98),
                                    Color(red: 0.98, green: 0.94, blue: 0.90)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

@MainActor
enum PostcardExporter {

    /// Renders the postcard (front and back) to a PNG in the temporary folder and returns its URL.
    /// ImageRenderer doesn't inherit the environment, so language, direction and tint are passed in.
    static func pngFile(for content: PostcardContent, tint: Color,
                        locale: Locale, layoutDirection: LayoutDirection) -> URL? {
        let view = PostcardExportView(content: content)
            .tint(tint)
            .environment(\.locale, locale)
            .environment(\.layoutDirection, layoutDirection)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2                                  // 1800 px wide
        renderer.proposedSize = ProposedViewSize(width: 900, height: nil)
        guard let data = renderer.uiImage?.pngData() else { return nil }

        let safeName = content.placeName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let fileName = "Postcard-\(safeName.isEmpty ? "Travel" : safeName).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            #if DEBUG
            // In the Simulator this is a real folder on your Mac: open it in Finder
            // (Go > Go to Folder…) to copy the sample PNG next to the project folder.
            print("Postcard PNG written to: \(url.path)")
            #endif
            return url
        } catch {
            print("Could not write the PNG: \(error)")
            return nil
        }
    }
}

#Preview {
    let content = PostcardContent(image: UIImage(systemName: "photo") ?? UIImage(),
                                  placeName: "Kyoto",
                                  message: "Greetings from Kyoto! The temples were beautiful and the food was even better.",
                                  sender: "Weiting",
                                  address: "Alex Chen\n500 Joseph C. Wilson Blvd\nRochester, NY 14627",
                                  date: .now)
    ScrollView {
        PostcardExportView(content: content)
            .scaleEffect(0.4)
            .frame(height: 560)
    }
    .accentTint()
}
