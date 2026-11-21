import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DiscoverView() }
                .tabItem { Label("发现", systemImage: "play.rectangle") }
            NavigationStack { PlaceholderView(title: "收藏", subtitle: "收藏功能将在播放主流程稳定后接入") }
                .tabItem { Label("收藏", systemImage: "heart") }
            NavigationStack { PlaceholderView(title: "设置", subtitle: "BiliX 1.0") }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .background(BiliTheme.background)
    }
}

struct DiscoverView: View {
    @State private var query = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("搜索 B站视频", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("videoSearchField")
                Text("推荐视频")
                    .font(.title2.bold())
                    .foregroundStyle(BiliTheme.primary)
                ContentUnavailableView("视频列表待接入", systemImage: "play.rectangle",
                                       description: Text("下一步接入 B站公开数据及播放链路"))
            }
            .padding(20)
        }
        .navigationTitle("发现")
        .background(BiliTheme.background)
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "rectangle.stack",
                               description: Text(subtitle))
            .navigationTitle(title)
            .background(BiliTheme.background)
    }
}
