import Foundation

struct BiliVideo: Identifiable, Hashable {
    let bvid: String
    let title: String
    let author: String
    let cover: URL?
    let publishedAt: Date
    let mid: Int?
    var id: String { bvid }
}

enum BiliAPI {
    enum APIError: LocalizedError {
        case invalidResponse
        case blocked
        var errorDescription: String? {
            switch self {
            case .invalidResponse: "B站接口返回了无法解析的数据。"
            case .blocked: "B站接口拒绝了本次请求；可能需要登录或调整接口方案。"
            }
        }
    }

    static func search(_ keyword: String) async throws -> [BiliVideo] {
        var components = URLComponents(string: "https://api.bilibili.com/x/web-interface/wbi/search/type")!
        components.queryItems = [
            URLQueryItem(name: "search_type", value: "video"),
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "page", value: "1")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 BiliX/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 else { throw APIError.blocked }
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard result.code == 0 else { throw APIError.blocked }
        return (result.data?.result ?? []).compactMap { item in
            guard let bvid = item.bvid, !bvid.isEmpty else { return nil }
            let raw = item.pic ?? ""
            let coverString = raw.hasPrefix("//") ? "https:" + raw : raw
            return BiliVideo(bvid: bvid,
                             title: (item.title ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
                             author: item.author ?? "未知UP主",
                             cover: URL(string: coverString),
                             publishedAt: Date(timeIntervalSince1970: TimeInterval(item.pubdate ?? 0)),
                             mid: item.mid)
        }
    }
}

private struct SearchResponse: Decodable {
    let code: Int
    let data: SearchData?
}
private struct SearchData: Decodable {
    let result: [SearchItem]?
}
private struct SearchItem: Decodable {
    let bvid: String?
    let title: String?
    let author: String?
    let pic: String?
    let pubdate: Int?
    let mid: Int?
}
