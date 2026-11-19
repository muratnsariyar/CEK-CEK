import SwiftData
import SwiftUI

struct FolderEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingFolder: MediaFolder? = nil

    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColorHex: String = "#FF9500"
    @State private var defaultRetentionDays: Int = 3

    private let iconOptions = [
        "folder.fill", "briefcase.fill", "doc.text.fill", "bolt.fill",
        "car.fill", "shippingbox.fill", "cart.fill", "wrench.and.screwdriver.fill",
        "tag.fill", "bookmark.fill", "building.2.fill", "camera.fill"
    ]

    private let colorOptions = [
        "#FF9500", "#007AFF", "#34C759", "#AF52DE",
        "#FF3B30", "#FF2D55", "#5AC8FA", "#8E8E93"
    ]

    private let retentionDayOptions = [1, 3, 7, 14, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section("Klasör Bilgileri") {
                    TextField("Klasör adı (örn: Kargo, Şantiye, Park)", text: $name)

                    Picker("Varsayılan Saklama Süresi", selection: $defaultRetentionDays) {
                        ForEach(retentionDayOptions, id: \.self) { days in
                            Text("\(days) Gün").tag(days)
                        }
                    }
                }

                Section("Simge") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedIcon == icon
                                            ? (Color(hex: selectedColorHex) ?? .orange)
                                            : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Renk") {
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .orange)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if selectedColorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(editingFolder == nil ? "Yeni Klasör" : "Klasörü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveFolder()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let folder = editingFolder {
                    name = folder.name
                    selectedIcon = folder.iconName
                    selectedColorHex = folder.colorHex
                    defaultRetentionDays = folder.defaultRetentionDays
                }
            }
        }
    }

    private func saveFolder() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let folder = editingFolder {
            folder.name = trimmed
            folder.iconName = selectedIcon
            folder.colorHex = selectedColorHex
            folder.defaultRetentionDays = defaultRetentionDays
        } else {
            let newFolder = MediaFolder(
                name: trimmed,
                iconName: selectedIcon,
                colorHex: selectedColorHex,
                defaultRetentionDays: defaultRetentionDays
            )
            modelContext.insert(newFolder)
        }
        try? modelContext.save()
        dismiss()
    }
}
