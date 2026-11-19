import SwiftData
import SwiftUI

enum GalleryFilter: String, CaseIterable, Identifiable {
    case all = "Tümü"
    case photos = "Fotoğraf"
    case videos = "Video"
    case expiringSoon = "Yakında Biten"

    var id: String { rawValue }
}

struct GalleryTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var allItems: [MediaItem]
    @Query(sort: \MediaFolder.createdAt) private var folders: [MediaFolder]

    @AppStorage("notificationLeadHours") private var notificationLeadHours: Int = 6

    var lockedFolder: MediaFolder? = nil

    @State private var selectedFilter: GalleryFilter = .all
    @State private var selectedFolderID: UUID? = nil
    @State private var searchText: String = ""
    @State private var selectedItem: MediaItem?
    @State private var isSelectionMode = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var showBatchShareSheet = false
    @State private var showBatchDeleteConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private var filteredItems: [MediaItem] {
        allItems.filter { item in
            guard !item.isExpired else { return false }

            if let lockedFolder {
                guard item.folder?.id == lockedFolder.id else { return false }
            } else if let selectedFolderID {
                guard item.folder?.id == selectedFolderID else { return false }
            }

            switch selectedFilter {
            case .all:
                break
            case .photos:
                guard item.mediaType == .photo else { return false }
            case .videos:
                guard item.mediaType == .video else { return false }
            case .expiringSoon:
                guard item.isExpiringSoon else { return false }
            }

            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                let query = searchText.lowercased()
                let noteMatches = item.note.lowercased().contains(query)
                let folderMatches = item.folder?.name.lowercased().contains(query) ?? false
                return noteMatches || folderMatches
            }

            return true
        }
    }

    private var selectedItems: [MediaItem] {
        filteredItems.filter { selectedItemIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if lockedFolder == nil {
                NavigationStack {
                    contentView
                }
            } else {
                contentView
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            filterHeader

            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(filteredItems) { item in
                            MediaGridItemView(
                                item: item,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedItemIDs.contains(item.id)
                            )
                            .onTapGesture {
                                if isSelectionMode {
                                    toggleSelection(for: item)
                                } else {
                                    selectedItem = item
                                }
                            }
                            .onLongPressGesture {
                                if !isSelectionMode {
                                    isSelectionMode = true
                                    selectedItemIDs = [item.id]
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }

            if isSelectionMode && !selectedItemIDs.isEmpty {
                batchActionBar
            }
        }
        .navigationTitle(lockedFolder?.name ?? "Geçici Galeri")
        .searchable(text: $searchText, prompt: "Not veya klasör ara")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !filteredItems.isEmpty {
                    Button(isSelectionMode ? "Bitti" : "Seç") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedItemIDs.removeAll()
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                MediaDetailView(item: item)
            }
        }
        .sheet(isPresented: $showBatchShareSheet) {
            let urls = selectedItems.map { MediaStorageService.shared.fileURL(for: $0.fileName) }
            ShareSheet(items: urls)
        }
        .confirmationDialog(
            "\(selectedItems.count) medya kalıcı olarak silinsin mi?",
            isPresented: $showBatchDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Hepsini Sil", role: .destructive) {
                for item in selectedItems {
                    ExpirationService.deleteItem(item, in: modelContext)
                }
                selectedItemIDs.removeAll()
                isSelectionMode = false
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private var filterHeader: some View {
        VStack(spacing: 8) {
            Picker("Filtre", selection: $selectedFilter) {
                ForEach(GalleryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            if lockedFolder == nil && !folders.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        folderChip(title: "Tümü", icon: "square.grid.2x2", color: .orange, isSelected: selectedFolderID == nil) {
                            selectedFolderID = nil
                        }
                        ForEach(folders) { folder in
                            folderChip(
                                title: folder.name,
                                icon: folder.iconName,
                                color: folder.color,
                                isSelected: selectedFolderID == folder.id
                            ) {
                                selectedFolderID = folder.id
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func folderChip(
        title: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.secondarySystemBackground), in: Capsule())
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Geçici Galeri Boş", systemImage: "photo.stack")
        } description: {
            Text("Çektiğiniz geçici fotoğraf ve videolar burada saklanır ve süresi dolduğunda otomatik temizlenir.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var batchActionBar: some View {
        HStack {
            Button {
                showBatchShareSheet = true
            } label: {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }

            Spacer()

            Menu {
                ForEach(RetentionPreset.allCases) { preset in
                    Button("+\(preset.title) Uzat") {
                        for item in selectedItems {
                            item.extend(by: preset)
                            NotificationService.shared.scheduleExpirationReminder(
                                for: item,
                                hoursBefore: notificationLeadHours
                            )
                        }
                        try? modelContext.save()
                        selectedItemIDs.removeAll()
                        isSelectionMode = false
                    }
                }
            } label: {
                Label("Uzat", systemImage: "clock.arrow.circlepath")
            }

            Spacer()

            Menu {
                ForEach(folders) { folder in
                    Button {
                        for item in selectedItems {
                            item.folder = folder
                        }
                        try? modelContext.save()
                        selectedItemIDs.removeAll()
                        isSelectionMode = false
                    } label: {
                        Label(folder.name, systemImage: folder.iconName)
                    }
                }
            } label: {
                Label("Taşı", systemImage: "folder")
            }

            Spacer()

            Button(role: .destructive) {
                showBatchDeleteConfirm = true
            } label: {
                Label("Sil (\(selectedItems.count))", systemImage: "trash")
            }
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func toggleSelection(for item: MediaItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }
}
