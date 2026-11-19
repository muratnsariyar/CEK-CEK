import SwiftUI

struct MediaGridItemView: View {
    let item: MediaItem
    let isSelectionMode: Bool
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    private var hasNote: Bool {
        !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay {
                            Image(systemName: item.mediaType.iconName)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }

                // Hafif alt gradyan (tek şerit okunabilirliği için)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 36)
                }

                // Üst köşeler: Sol üstte not kalem simgesi, sağ üstte seçim işareti
                VStack {
                    HStack {
                        if hasNote {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.black.opacity(0.48), in: Circle())
                        }

                        Spacer()

                        if isSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? .orange : .white)
                                .shadow(radius: 2)
                        }
                    }
                    .padding(6)

                    Spacer()

                    // Alt tek şerit: Sol kalan süre, sağ video süresi (asla alt satıra kırılmaz)
                    HStack(spacing: 4) {
                        Text(item.remainingBadgeText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(badgeColor, in: Capsule())

                        Spacer(minLength: 2)

                        if item.mediaType == .video {
                            HStack(spacing: 2) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8))
                                if let duration = item.formattedDuration {
                                    Text(duration)
                                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                }
                            }
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2.5)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: item.thumbnailFileName ?? item.fileName) {
            let name = item.thumbnailFileName ?? item.fileName
            thumbnail = MediaStorageService.shared.loadImage(fileName: name)
        }
    }

    private var badgeColor: Color {
        if item.isCritical {
            return .red.opacity(0.88)
        } else if item.isExpiringSoon {
            return .orange.opacity(0.88)
        } else {
            return .black.opacity(0.52)
        }
    }
}
