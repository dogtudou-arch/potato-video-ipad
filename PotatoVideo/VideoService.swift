import Foundation
import UIKit

struct Source: Hashable, Codable, Sendable {
    let name: String
    let url: String

    static let all: [Source] = [
        .init(name: "红牛资源", url: "https://www.hongniuzy2.com/api.php/provide/vod"),
        .init(name: "魔都资源", url: "https://www.mdzyapi.com/api.php/provide/vod"),
        .init(name: "量子资源", url: "https://cj.lziapi.com/api.php/provide/vod"),
        .init(name: "暴风资源", url: "https://bfzyapi.com/api.php/provide/vod"),
        .init(name: "非凡资源", url: "https://api.ffzyapi.com/api.php/provide/vod"),
        .init(name: "电影天堂", url: "https://caiji.dyttzyapi.com/api.php/provide/vod")
    ]
}

struct Video: Identifiable, Hashable, Codable, Sendable {
    let source: Source
    let vodID: String
    let title: String
    let year: String
    let remarks: String
    let version: String

    var id: String { source.url + "|" + vodID }

    var details: String {
        [year, remarks, quality].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var quality: String {
        if let measured = UserDefaults.standard.string(forKey: "quality_" + id), !measured.isEmpty {
            return "实测 " + measured
        }
        let text = version + " " + remarks + " " + title
        let pattern = "(?i)(2160p|4k|1080p|720p|480p|蓝光|超清|高清|标清)"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return "标注 " + text[range].uppercased()
        }
        return ""
    }
}

struct FavoriteFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var videos: [Video]
}

struct Episode: Identifiable, Hashable {
    let name: String
    let url: URL
    var id: String { name + "|" + url.absoluteString }
}

enum UsageWindow {
    private static let startKey = "usage_start"
    private static let seenKey = "usage_last_seen"
    private static let deviceKey = "usage_device"
    private static let validity: TimeInterval = 36_500 * 24 * 60 * 60

    static func isActive() -> Bool {
        let defaults = UserDefaults.standard
        guard let device = UIDevice.current.identifierForVendor?.uuidString else { return false }
        let now = Date().timeIntervalSince1970
        if defaults.object(forKey: startKey) == nil && defaults.object(forKey: seenKey) == nil && defaults.object(forKey: deviceKey) == nil {
            defaults.set(now, forKey: startKey)
            defaults.set(now, forKey: seenKey)
            defaults.set(device, forKey: deviceKey)
        }
        let start = defaults.double(forKey: startKey)
        let seen = defaults.double(forKey: seenKey)
        guard start > 0, seen >= start, defaults.string(forKey: deviceKey) == device else { return false }
        let effectiveNow = max(now, seen)
        if effectiveNow - seen >= 60 || effectiveNow - start >= validity {
            defaults.set(effectiveNow, forKey: seenKey)
        }
        return effectiveNow - start < validity
    }
}

enum VideoAPI {
    enum Failure: Error { case unavailable, invalidResponse }

    private static func fetch(_ source: Source, query: [URLQueryItem]) async throws -> [[String: Any]] {
        guard UsageWindow.isActive() else { throw Failure.unavailable }
        guard var components = URLComponents(string: source.url) else { throw Failure.invalidResponse }
        components.queryItems = query
        guard let url = components.url else { throw Failure.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard UsageWindow.isActive(), (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["list"] as? [[String: Any]] else { throw Failure.invalidResponse }
        return list
    }

    static func search(_ title: String, source: Source) async throws -> [Video] {
        let list = try await fetch(source, query: [
            .init(name: "ac", value: "videolist"),
            .init(name: "wd", value: title),
            .init(name: "pg", value: "1")
        ])
        return list.compactMap { item in
            let name = string(item["vod_name"])
            guard !name.isEmpty else { return nil }
            return Video(source: source, vodID: string(item["vod_id"]), title: name,
                         year: string(item["vod_year"]), remarks: string(item["vod_remarks"]),
                         version: string(item["vod_version"]))
        }
    }

    static func episodes(for video: Video) async throws -> [Episode] {
        let list = try await fetch(video.source, query: [
            .init(name: "ac", value: "videolist"),
            .init(name: "ids", value: video.vodID)
        ])
        guard let item = list.first else { throw Failure.invalidResponse }
        let playURL = string(item["vod_play_url"])
        var fallback: [Episode] = []
        for group in playURL.components(separatedBy: "$$$") {
            let episodes: [Episode] = group.components(separatedBy: "#").compactMap { entry in
                guard let split = entry.firstIndex(of: "$"),
                      let url = URL(string: String(entry[entry.index(after: split)...])),
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
                return Episode(name: String(entry[..<split]), url: url)
            }
            if episodes.isEmpty { continue }
            if fallback.isEmpty { fallback = episodes }
            if episodes.contains(where: { $0.url.absoluteString.contains(".m3u8") }) { return episodes }
        }
        return fallback
    }

    private static func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }
}
