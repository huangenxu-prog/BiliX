import SwiftUI

struct FeedCard: View {
    let video: BiliVideo
    @Binding var playing: String?
    @EnvironmentObject private var library: LocalLibrary
    @State private var expanded = false
    @State private var descriptionText: String?
    @State private var related: [BiliVideo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.black.aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    if playing == video.id {
                        BiliWebPlayer(bvid: video.id, autoplay: true) { library.watched(video) }
                    } else {
                        Button { playing = video.id } label: {
                            GeometryReader { bounds in
                                AsyncImage(url: video.cover) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { BiliTheme.divider }
                                .frame(width: bounds.size.width, height: bounds.size.height)
                                .clipped()
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if !video.duration.isEmpty {
                                    Text(video.duration).font(.caption).foregroundStyle(.white).padding(4)
                                        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 4)).padding(7)
                                }
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("播放" + video.title)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button { expanded.toggle() } label: {
                Text(video.title).font(.headline).foregroundStyle(BiliTheme.primary)
                    .lineLimit(expanded ? nil : 2).multilineTextAlignment(.leading)
            }.buttonStyle(.plain)
            HStack(spacing: 5) {
                NavigationLink { CreatorVideosView(author: video.author, mid: video.mid) } label: {
                    Text(video.author).lineLimit(1)
                }
                Text("·")
                Text(BiliTime.relative(video.publishedAt)).fixedSize()
                Button { library.toggle(video) } label: {
                    Image(systemName: library.contains(video) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(library.contains(video) ? BiliTheme.accent : BiliTheme.secondary)
                        .frame(width: 44, height: 44)
                }.accessibilityLabel(library.contains(video) ? "取消收藏" : "收藏")
            }.font(.subheadline).foregroundStyle(BiliTheme.secondary).buttonStyle(.plain)
            if expanded {
                if let descriptionText, !descriptionText.isEmpty { Text(descriptionText).font(.footnote) }
                if !related.isEmpty {
                    NavigationLink("相关推荐") { SavedVideos(title: "相关推荐", videos: related) }
                }
            }
        }
        .task(id: expanded) {
            guard expanded, descriptionText == nil else { return }
            async let desc = BiliAPI.description(for: video.id)
            async let items = BiliAPI.related(to: video.id)
            descriptionText = try? await desc
            related = (try? await items) ?? []
        }
        .onDisappear { if playing == video.id { playing = nil } }
    }
}
