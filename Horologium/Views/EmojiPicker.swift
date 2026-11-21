import SwiftUI

struct EmojiPicker: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category = "Country flags"
    @State private var catalog: EmojiCatalog?
    @State private var error: String?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    init(selection: Binding<String?>, initialCatalog: EmojiCatalog? = nil) {
        _selection = selection
        _catalog = State(initialValue: initialCatalog)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose an emoji").font(.headline)
                Spacer()
                Button("No emoji") { selection = nil; dismiss() }.font(.caption)
            }
            TextField("Search emoji or countries", text: $query).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search emoji")
            Picker("Category", selection: $category) {
                Text("All emoji").tag("All emoji")
                Text("Country flags").tag("Country flags")
                ForEach(groups, id: \.self) { Text($0).tag($0) }
            }
            if let catalog {
                let matches = catalog.search(query, category: category)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(matches) { entry in
                            Button {
                                selection = entry.glyph
                                dismiss()
                            } label: {
                                Text(entry.glyph).font(.system(size: 25))
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(selection == entry.glyph ? Color.accentColor.opacity(0.18) : .clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).help(entry.name).accessibilityLabel(entry.name)
                            .accessibilityAddTraits(selection == entry.glyph ? .isSelected : [])
                        }
                    }.padding(2)
                }
                .id(category + query)
                .overlay { if matches.isEmpty { ContentUnavailableView.search(text: query) } }
                Text("\(matches.count) emoji · Country flags appear first")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if let error {
                ContentUnavailableView("Emoji unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16).frame(width: 370, height: 410)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            do { catalog = try EmojiCatalog.bundled() }
            catch { self.error = error.localizedDescription }
        }
    }

    private var groups: [String] { Array(Set(catalog?.entries.map(\.group) ?? [])).sorted() }
}
