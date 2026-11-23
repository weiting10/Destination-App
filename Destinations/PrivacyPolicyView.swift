//
//  PrivacyPolicyView.swift
//  Destinations
//
//  Shows PrivacyPolicy.md, a localized document bundled with the app
//  (en.lproj/PrivacyPolicy.md and ar.lproj/PrivacyPolicy.md). Bundle.main picks the
//  copy that matches the app's language automatically.
//  Supports the small subset of Markdown the document uses:
//  "# " title, "## " heading, "- " bullet, paragraphs, and **bold** / links inside lines.
//

import SwiftUI

struct PrivacyPolicyView: View {

    @Environment(\.dismiss) private var dismiss

    private let blocks = PrivacyPolicyView.loadBlocks()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if blocks.isEmpty {
                        Text("The privacy policy couldn't be loaded.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color("background_color").ignoresSafeArea())
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Rendering

    private enum Block {
        case title(String)
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .title(let text):
            Text(inline(text))
                .font(.largeTitle.bold())
        case .heading(let text):
            Text(inline(text))
                .font(.title3.bold())
                .padding(.top, 8)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "•")
                Text(inline(text))
            }
        case .paragraph(let text):
            Text(inline(text))
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    // MARK: Loading

    private static func loadBlocks() -> [Block] {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var blocks: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.title(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        return blocks
    }
}

#Preview {
    PrivacyPolicyView()
}
