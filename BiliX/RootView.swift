import SwiftUI
import WebKit

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DiscoverView() }
                .tabItem { Label("发现", systemImage: "play.rectangle") }
            NavigationStack { PlaceholderView(title: "收藏", subtitle: "稍后接入本地收藏") }
                .tabItem { Label("收藏", systemImage: "bookmark") }
            NavigationStack { PlaceholderView(title: "设置", subtitle: "BiliX 1.0") }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .background(BiliTheme.background)
    }
}

struct DiscoverView: View {
    @State private var query = ""
    @State private var videos: [BiliVideo] = []
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索 B站视频", text: $query)
                            .submitLabel(.search)
                            .onSubmit { Task { await search() } }
                            .accessibilityIdentifier("videoSearchField")
                        if !query.isEmpty {
                            Button { query = ""; videos = []; error = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(BiliTheme.divider, in: RoundedRectangle(cornerRadius: 15))
                    if loading { ProgressView("正在搜索…").frame(maxWidth: .infinity) }
                    if let error {
                        ContentUnavailableView("暂时无法获取视频", systemImage: "wifi.exclamationmark", description: Text(error))
                    }
                    if !loading && error == nil && videos.isEmpty {
                        ContentUnavailableView("搜索视频", systemImage: "play.rectangle", description: Text("输入关键词并点击键盘上的搜索"))
                    }
                    ForEach(videos) { video in
                        NavigationLink(value: video) { VideoRow(video: video) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .navigationTitle("发现")
            .navigationDestination(for: BiliVideo.self) { VideoDetailView(video: $0) }
            .background(BiliTheme.background)
        }
    }
    @MainActor private func search() async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        loading = true; error = nil; videos = []
        defer { loading = false }
        do { videos = try await BiliAPI.search(keyword) }
        catch { self.error = error.localizedDescription }
    }
}

struct VideoRow: View {
    let video: BiliVideo
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: video.cover) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                BiliTheme.divider.overlay { Image(systemName: "play.rectangle").foregroundStyle(.secondary) }
            }
            .frame(width: 142, height: 85)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title).font(.subheadline.weight(.medium)).foregroundStyle(BiliTheme.primary).lineLimit(2)
                Spacer(minLength: 0)
                Text(video.author).font(.caption).foregroundStyle(BiliTheme.secondary).lineLimit(1)
                Text(video.publishedAt, style: .relative).font(.caption2).foregroundStyle(BiliTheme.secondary)
            }
            .frame(height: 85, alignment: .top)
            Spacer(minLength: 0)
        }
    }
}

struct VideoDetailView: View {
    let video: BiliVideo
    @State private var expanded = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                BiliWebPlayer(bvid: video.bvid)
                    .frame(height: 225)
                    .background(.black)
                Button { expanded.toggle() } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title).font(.headline).foregroundStyle(BiliTheme.primary)
                        Text(video.publishedAt, style: .relative).font(.caption).foregroundStyle(BiliTheme.secondary)
                        if expanded { Text("视频说明请在原视频页面查看。").font(.footnote).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    CreatorVideosView(author: video.author, mid: video.mid)
                } label: {
                    HStack {
                        Text(video.author).foregroundStyle(BiliTheme.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(BiliTheme.secondary)
                    }
                    .padding(.vertical, 10)
                }
                Divider()
                Text("相关推荐").font(.headline)
                Text("相关推荐将在数据接口验证后接入。").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CreatorVideosView: View {
    let author: String
    let mid: Int?
    var body: some View {
        ContentUnavailableView("作者作品", systemImage: "play.rectangle.on.rectangle",
            description: Text(mid == nil ? "当前数据缺少作者 ID，暂无法获取作品。" : "作者作品接口待接入验证。"))
            .navigationTitle(author)
    }
}

struct BiliWebPlayer: UIViewRepresentable {
    let bvid: String
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .black
        view.configuration.allowsInlineMediaPlayback = true
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        guard let safe = bvid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://player.bilibili.com/player.html?bvid=\(safe)&autoplay=0") else { return }
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "rectangle.stack", description: Text(subtitle))
            .navigationTitle(title)
    }
}
