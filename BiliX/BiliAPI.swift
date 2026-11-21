import Foundation
import CryptoKit

struct BiliVideo: Identifiable, Hashable, Codable {
    let bvid: String
    let title: String
    let author: String
    let cover: URL?
    let publishedAt: Date
    let mid: Int?
    let duration: String
    var id: String { bvid }
}

enum BiliAPI {
    typealias Object = [String: Any]
    struct Failure: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }
    static func request(_ path: String, _ query: String = "") async throws -> Object {
        var parts = URLComponents(string: "https://api.bilibili.com" + path)!
        parts.percentEncodedQuery = query.isEmpty ? nil : query
        var request = URLRequest(url: parts.url!)
        request.timeoutInterval = 18
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let root = try JSONSerialization.jsonObject(with: data) as? Object else {
            throw Failure(reason: "暂时无法读取 B站响应")
        }
        return root
    }
    static func payload(_ path: String, _ params: [String: String], signed: Bool = false) async throws -> Any {
        var args = params
        var key = ""
        if signed {
            let nav = try await request("/x/web-interface/nav")
            guard let data = nav["data"] as? Object, let images = data["wbi_img"] as? Object else {
                throw Failure(reason: "无法获取搜索签名")
            }
            let source = ["img_url", "sub_url"].compactMap { (images[$0] as? String).flatMap(URL.init(string:))?.deletingPathExtension().lastPathComponent }.joined()
            let bytes = Array(source.utf8)
            guard bytes.count == 64 else { throw Failure(reason: "接口签名无效") }
            let order = [46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,33,9,42,19,29,28,14,39,12,38,41,13]
            key = String(decoding: order.map { bytes[$0] }, as: UTF8.self)
            args["wts"] = String(Int(Date().timeIntervalSince1970))
        }
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var query = args.keys.sorted().map { name in
            let value = args[name] ?? ""
            let filtered = signed ? value.filter { !"!'()*".contains($0) } : value
            return name + "=" + (filtered.addingPercentEncoding(withAllowedCharacters: safe) ?? "")
        }.joined(separator: "&")
        if signed {
            let digest = Insecure.MD5.hash(data: Data((query + key).utf8))
            query += "&w_rid=" + digest.map { String(format: "%02x", $0) }.joined()
        }
        let root = try await request(path, query)
        guard root["code"] as? Int == 0, let data = root["data"] else {
            throw Failure(reason: root["message"] as? String ?? "B站暂未返回数据")
        }
        return data
    }

    static func videos(_ raw: Any?) throws -> [BiliVideo] {
        guard let rows = raw as? [Object] else { throw Failure(reason: "视频列表格式异常") }
        var seen = Set<String>()
        return rows.compactMap { row in
            guard let id = row["bvid"] as? String, !id.isEmpty, seen.insert(id).inserted,
                  let title = row["title"] as? String else { return nil }
            let owner = row["owner"] as? Object ?? [:]
            var pic = row["pic"] as? String ?? ""
            if pic.hasPrefix("//") { pic = "https:" + pic }
            pic = pic.replacingOccurrences(of: "http://", with: "https://")
            let seconds = row["duration"] as? Int
            let duration = seconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
            return BiliVideo(bvid: id, title: title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
                author: owner["name"] as? String ?? row["author"] as? String ?? "",
                cover: URL(string: pic), publishedAt: Date(timeIntervalSince1970: Double(row["pubdate"] as? Int ?? row["created"] as? Int ?? 0)),
                mid: owner["mid"] as? Int ?? row["mid"] as? Int,
                duration: duration ?? row["duration"] as? String ?? row["length"] as? String ?? "")
        }
    }

    static func region(_ id: Int) async throws -> [BiliVideo] {
        let data = try await payload("/x/web-interface/newlist", ["rid":String(id), "ps":"20", "pn":"1"]) as? Object
        return try videos(data?["archives"])
    }
    static func feed() async throws -> [BiliVideo] {
        let data = try await payload("/x/web-interface/wbi/index/top/feed/rcmd", ["ps":"20", "fresh_type":"3", "fresh_idx":"1"], signed: true) as? Object
        return try videos(data?["item"])
    }
    static func search(_ keyword: String) async throws -> [BiliVideo] {
        let data = try await payload("/x/web-interface/wbi/search/type", ["search_type":"video", "keyword":keyword, "page":"1"], signed: true) as? Object
        return try videos(data?["result"])
    }
    static func creator(_ mid: Int, page: Int) async throws -> ([BiliVideo], Bool) {
        let data = try await payload("/x/space/wbi/arc/search", ["mid":String(mid),"pn":String(page),"ps":"30","order":"pubdate"], signed: true) as? Object
        let result = try videos((data?["list"] as? Object)?["vlist"])
        let count = (data?["page"] as? Object)?["count"] as? Int
        return (result, !result.isEmpty && (count.map { page * 30 < $0 } ?? (result.count == 30)))
    }
    static func related(to bvid: String) async throws -> [BiliVideo] {
        try await videos(payload("/x/web-interface/archive/related", ["bvid":bvid]))
    }
    static func description(for bvid: String) async throws -> String {
        let data = try await payload("/x/web-interface/view", ["bvid":bvid]) as? Object
        return data?["desc"] as? String ?? ""
    }
}
