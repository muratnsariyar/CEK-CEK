import SwiftData
import SwiftUI

struct FoldersTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaFolder.createdAt) private var folders: [MediaFolder]

    @State private var showCreateSheet = false
    @State private var editingFolder: MediaFolder?

    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    NavigationLink {
                        GalleryTabView(lockedFolder: folder)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: folder.iconName)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(folder.color, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(folder.name)
                                    .font(.headline)
                                Text("Varsayılan süre: \(folder.defaultRetentionDays) gün")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(folder.activeItems.count)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !folder.isSystemDefault {
                            Button(role: .destructive) {
                                modelContext.delete(folder)
                                try? modelContext.save()
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }

                        Button {
                            editingFolder = folder
                        } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Klasörler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                FolderEditorSheet()
            }
            .sheet(item: $editingFolder) { folder in
                FolderEditorSheet(editingFolder: folder)
            }
        }
    }
}
