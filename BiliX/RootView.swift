import SwiftUI
import WebKit

struct RootView: View {
    @StateObject private var library = LocalLibrary()
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("发现", systemImage: "play.rectangle") }
            NavigationStack { SavedVideos(title: "收藏", videos: library.favorites) }
                .tabItem { Label("收藏", systemImage: "bookmark") }
            NavigationStack {
                List {
                    NavigationLink("观看历史") { SavedVideos(title: "观看历史", videos: library.history) }
                }.navigationTitle("设置")
            }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .environmentObject(library)
        .preferredColorScheme(.light)
        .background(BiliTheme.background)
    }
}

struct DiscoverView: View {
    @State private var query = ""
    @State private var submitted = ""
    @State private var revision = 0
    @State private var region = 0
    @State private var playing: String?
    private let regions = [(0,"推荐"), (181,"影视"), (3,"音乐"), (36,"知识"), (188,"科技"), (160,"生活"), (4,"游戏"), (1,"动画")]
    @State private var videos: [BiliVideo] = []
    @State private var loadedRevision: Int?
    @State private var nextPage = 1
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?
    @State private var paginationNotice: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索 B站视频", text: $query)
                            .submitLabel(.search)
                            .onSubmit { submitted = query.trimmingCharacters(in: .whitespacesAndNewlines); revision += 1 }
                            .accessibilityIdentifier("videoSearchField")
                        if !query.isEmpty {
                            Button { query = ""; submitted = ""; revision += 1 } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(BiliTheme.divider, in: RoundedRectangle(cornerRadius: 15))
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(regions, id: \.0) { item in
                                Button(item.1) {
                                    query = ""
                                    submitted = ""
                                    region = item.0
                                    revision += 1
                                }
                                .foregroundStyle(region == item.0 && submitted.isEmpty ? BiliTheme.accent : BiliTheme.secondary)
                            }
                        }
                    }.scrollIndicators(.hidden)
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        FeedCard(video: video, playing: $playing)
                            .onAppear {
                                // Prefetch when the user scrolls near the end.
                                // This also works when the footer is not visible.
                                guard hasMore, index >= videos.count - 4 else { return }
                                let current = revision
                                Task { await loadPage(current) }
                            }
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(BiliTheme.secondary)
                        Button("重试") { Task { await loadPage(revision) } }
                    } else if loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if !videos.isEmpty {
                        // No manual "load more" button: scroll near the last cards
                        // to fetch the next batch automatically.
                        if let paginationNotice {
                            Text(paginationNotice)
                                .font(.caption2)
                                .foregroundStyle(BiliTheme.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    } else if !hasMore && videos.isEmpty {
                        ContentUnavailableView("暂无视频", systemImage: "play.rectangle")
                    }
                }
                .padding(18)
            }
            .task(id: revision) {
                if loadedRevision != revision {
                    loadedRevision = revision
                    playing = nil
                    videos = []
                    nextPage = 1
                    loading = false
                    hasMore = true
                    error = nil
                    paginationNotice = nil
                }
                if nextPage == 1 { await loadPage(revision) }
            }
            .onDisappear { playing = nil }
            .navigationTitle("发现")
            .background(BiliTheme.background)
        }
    }
    @MainActor private func loadPage(_ requestRevision: Int) async {
        guard revision == requestRevision, loadedRevision == revision, !loading else { return }
        loading = true
        error = nil
        paginationNotice = nil
        defer { if revision == requestRevision { loading = false } }
        do {
            // Some B站 category pages overlap heavily. A duplicate-only page
            // does not prove the feed has ended; inspect a few subsequent pages.
            var known = Set(videos.map(\.id))
            var additions: [BiliVideo] = []
            var reachedEnd = false
            // Fetch enough pages to fill a useful batch, not just one new item.
            for _ in 0..<6 {
                let result: [BiliVideo]
                if !submitted.isEmpty { result = try await BiliAPI.search(submitted, page: nextPage) }
                else if region == 0 { result = try await BiliAPI.feed(page: nextPage) }
                else { result = try await BiliAPI.region(region, page: nextPage) }
                guard revision == requestRevision, !Task.isCancelled else { return }
                nextPage += 1
                if result.isEmpty {
                    reachedEnd = true
                    break
                }
                let unique = result.filter { known.insert($0.id).inserted }
                additions.append(contentsOf: unique)
                if additions.count >= 15 { break }
            }
            videos.append(contentsOf: additions)
            // Never hide the manual retry control based solely on duplicates.
            // Avoid automatic request loops when an endpoint returns no new items.
            hasMore = !reachedEnd && !additions.isEmpty
            if additions.isEmpty {
                paginationNotice = reachedEnd ? "当前接口返回空页，点击可重新尝试" : "连续几页内容重复，点击可继续查找"
            }
        } catch {
            guard revision == requestRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
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
            .overlay(alignment: .bottomTrailing) {
                if !video.duration.isEmpty {
                    Text(video.duration).font(.caption2).foregroundStyle(.white).padding(3)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4)).padding(4)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title).font(.subheadline.weight(.medium)).foregroundStyle(BiliTheme.primary).lineLimit(2)
                Spacer(minLength: 0)
                Text(video.author).font(.caption).foregroundStyle(BiliTheme.secondary).lineLimit(1)
                Text(BiliTime.relative(video.publishedAt)).font(.caption2).foregroundStyle(BiliTheme.secondary)
            }
            .frame(height: 85, alignment: .top)
            Spacer(minLength: 0)
        }
    }
}

struct VideoDetailView: View {
    let video: BiliVideo
    @EnvironmentObject private var library: LocalLibrary
    @State private var expanded = false
    @State private var descriptionText = ""
    @State private var related: [BiliVideo] = []
    @State private var relatedError: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                BiliWebPlayer(bvid: video.bvid) { library.watched(video) }
                    .frame(height: 225)
                    .background(.black)
                Button { expanded.toggle() } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title).lineLimit(expanded ? nil : 2).font(.headline).foregroundStyle(BiliTheme.primary)
                        Text(BiliTime.relative(video.publishedAt)).font(.caption).foregroundStyle(BiliTheme.secondary)
                        if expanded && !descriptionText.isEmpty { Text(descriptionText).font(.footnote).foregroundStyle(.secondary) }
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
                if let relatedError { Text(relatedError).font(.footnote).foregroundStyle(.secondary) }
                ForEach(related) { item in
                    VideoLink(video: item).buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: video.bvid) {
            descriptionText = ""
            related = []
            relatedError = nil
            async let desc = BiliAPI.description(for: video.bvid)
            async let recommendations = BiliAPI.related(to: video.bvid)
            descriptionText = (try? await desc) ?? ""
            do { related = try await recommendations }
            catch { relatedError = "暂时无法加载相关推荐" }
        }
    }
}

struct CreatorVideosView: View {
    let author: String
    let mid: Int?
    @State private var works: [BiliVideo] = []
    @State private var page = 1
    @State private var more = true
    @State private var loading = false
    @State private var failure: String?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(works) { VideoLink(video: $0) }
                if let failure { Text(failure).font(.footnote) }
                if loading { ProgressView() }
                else if more && mid != nil { Button(failure == nil ? "加载更多" : "重试") { Task { await load() } } }
                else if works.isEmpty { Text(mid == nil ? "缺少作者 ID" : "暂无公开视频") }
            }.padding()
        }.navigationTitle(author).task { if works.isEmpty { await load() } }
    }
    @MainActor private func load() async {
        guard let mid, !loading, more else { return }
        loading = true
        defer { loading = false }
        do {
            let (items, hasMore) = try await BiliAPI.creator(mid, page: page)
            let known = Set(works.map(\.id))
            works += items.filter { !known.contains($0.id) }
            more = hasMore
            page += 1
            failure = nil
        } catch { failure = error.localizedDescription }
    }
}

struct VideoLink: View {
    @EnvironmentObject private var library: LocalLibrary
    let video: BiliVideo
    var body: some View {
        NavigationLink { VideoDetailView(video: video) } label: { VideoRow(video: video) }
            .buttonStyle(.plain).contextMenu {
                Button(library.contains(video) ? "取消收藏" : "收藏") { library.toggle(video) }
            }
    }
}

struct SavedVideos: View {
    let title: String
    let videos: [BiliVideo]
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) { ForEach(videos) { VideoLink(video: $0) } }.padding()
        }.overlay { if videos.isEmpty { ContentUnavailableView("暂无" + title, systemImage: "play.rectangle") } }
        .navigationTitle(title)
    }
}

enum BiliTime {
    static func relative(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60)分钟前" }
        if seconds < 86400 { return "\(seconds / 3600)小时前" }
        if seconds < 604800 { return "\(seconds / 86400)天前" }
        if seconds < 2592000 { return "\(seconds / 604800)周前" }
        if seconds < 31536000 { return "\(seconds / 2592000)个月前" }
        return "\(seconds / 31536000)年前"
    }
}
