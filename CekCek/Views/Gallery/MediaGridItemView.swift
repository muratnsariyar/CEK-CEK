import SwiftUI

struct MediaGridItemView: View {
    let item: MediaItem
    let isSelectionMode: Bool
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
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

                // Alt gradyan
                LinearGradient(
                    colors: [.clear, .black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Kalan süre rozeti + Video süresi
                HStack(spacing: 4) {
                    Text(item.remainingBadgeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(badgeColor, in: Capsule())

                    Spacer()

                    if item.mediaType == .video {
                        HStack(spacing: 2) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9))
                            if let duration = item.formattedDuration {
                                Text(duration)
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .padding(6)

                // Seçim modu işareti
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? .orange : .white)
                                .shadow(radius: 2)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
            return .red.opacity(0.9)
        } else if item.isExpiringSoon {
            return .orange.opacity(0.9)
        } else {
            return .black.opacity(0.65)
        }
    }
}
