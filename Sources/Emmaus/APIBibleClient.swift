import Foundation

struct APIConfig: Codable {
    var endpoint: String
    var key: String
    var bibles: [String: String]

    static func load() -> APIConfig? {
        guard let data = try? Data(contentsOf: AppPaths.config) else { return nil }
        return try? JSONDecoder().decode(APIConfig.self, from: data)
    }

    func save() throws {
        AppPaths.ensureSupportDirectory()
        let data = try JSONEncoder().encode(self)
        try data.write(to: AppPaths.config, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: AppPaths.config.path)
    }
}

enum APIError: Error, LocalizedError {
    case notConfigured
    case http(Int, String)
    case badResponse(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "API.Bible is not configured. Add your key in Settings."
        case .http(let code, let m): return "API.Bible error \(code): \(m)"
        case .badResponse(let m): return "Unexpected response: \(m)"
        case .offline: return "You appear to be offline."
        }
    }
}

final class APIBibleClient {
    private(set) var config: APIConfig?

    static let bookIDs: [String] = [
        "GEN","EXO","LEV","NUM","DEU","JOS","JDG","RUT","1SA","2SA","1KI","2KI","1CH","2CH",
        "EZR","NEH","EST","JOB","PSA","PRO","ECC","SNG","ISA","JER","LAM","EZK","DAN","HOS",
        "JOL","AMO","OBA","JON","MIC","NAM","HAB","ZEP","HAG","ZEC","MAL","MAT","MRK","LUK",
        "JHN","ACT","ROM","1CO","2CO","GAL","EPH","PHP","COL","1TH","2TH","1TI","2TI","TIT",
        "PHM","HEB","JAS","1PE","2PE","1JN","2JN","3JN","JUD","REV"
    ]

    init() { reload() }

    func reload() { config = APIConfig.load() }

    var isConfigured: Bool { config != nil && !(config?.key.isEmpty ?? true) }

    func bibleID(for translation: Translation) -> String? {
        if !translation.bibleId.isEmpty { return translation.bibleId }
        return config?.bibles[translation.code]
    }

    private func request(path: String) async throws -> Data {
        guard let config, !config.key.isEmpty else { throw APIError.notConfigured }
        let base = config.endpoint.hasSuffix("/") ? String(config.endpoint.dropLast()) : config.endpoint
        guard let url = URL(string: base + path) else { throw APIError.badResponse("Invalid endpoint") }
        var req = URLRequest(url: url)
        req.setValue(config.key, forHTTPHeaderField: "api-key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 25
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.badResponse("No HTTP response") }
            if http.statusCode != 200 {
                let text = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
                throw APIError.http(http.statusCode, String(text))
            }
            return data
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.offline
        }
    }

    struct ChapterPayload: Decodable {
        struct DataBox: Decodable {
            var content: String
            var copyright: String?
        }
        var data: DataBox
    }

    private struct BiblePayload: Decodable {
        struct DataBox: Decodable {
            var name: String
            var copyright: String?
            var promotionalContent: String?
        }
        var data: DataBox
    }

    func chapter(translation: Translation, bookIndex: Int, chapter: Int) async throws -> (verses: [Int: String], copyright: String) {
        guard let bibleId = bibleID(for: translation) else { throw APIError.notConfigured }
        guard bookIndex >= 1 && bookIndex <= 66 else { throw APIError.badResponse("Bad book") }
        let book = Self.bookIDs[bookIndex - 1]
        let path = "/v1/bibles/\(bibleId)/chapters/\(book).\(chapter)?content-type=text&include-notes=false&include-titles=false&include-chapter-numbers=false&include-verse-numbers=true&include-verse-spans=false"
        let data = try await request(path: path)
        let payload = try JSONDecoder().decode(ChapterPayload.self, from: data)
        let verses = Self.parseVerses(payload.data.content)
        if verses.isEmpty { throw APIError.badResponse("No verses in chapter") }
        return (verses, payload.data.copyright ?? translation.attribution)
    }

    func bibleMetadata(translation: Translation) async throws -> (name: String, copyright: String?) {
        guard let bibleId = bibleID(for: translation) else { throw APIError.notConfigured }
        let data = try await request(path: "/v1/bibles/\(bibleId)")
        let payload = try JSONDecoder().decode(BiblePayload.self, from: data)
        return (payload.data.name, payload.data.copyright)
    }

    static func parseVerses(_ content: String) -> [Int: String] {
        var result: [Int: String] = [:]
        let pattern = try! NSRegularExpression(pattern: #"\[(\d+)\]"#)
        let ns = content as NSString
        let matches = pattern.matches(in: content, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else {
            let t = clean(content)
            if !t.isEmpty { result[1] = t }
            return result
        }
        for (i, m) in matches.enumerated() {
            guard let numRange = Range(m.range(at: 1), in: content),
                  let v = Int(content[numRange]) else { continue }
            let start = m.range.location + m.range.length
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            if end > start {
                let raw = ns.substring(with: NSRange(location: start, length: end - start))
                let t = clean(raw)
                if !t.isEmpty { result[v] = t }
            }
        }
        return result
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testConnection() async -> Result<Int, Error> {
        guard let config, !config.key.isEmpty else { return .failure(APIError.notConfigured) }
        let base = config.endpoint.hasSuffix("/") ? String(config.endpoint.dropLast()) : config.endpoint
        guard let url = URL(string: base + "/v1/bibles?language=eng") else { return .failure(APIError.badResponse("Bad endpoint")) }
        var req = URLRequest(url: url)
        req.setValue(config.key, forHTTPHeaderField: "api-key")
        req.timeoutInterval = 20
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .failure(APIError.badResponse("No response")) }
            if http.statusCode != 200 { return .failure(APIError.http(http.statusCode, String(data: data.prefix(200), encoding: .utf8) ?? "")) }
            struct ListPayload: Decodable { struct B: Decodable { var id: String }; var data: [B] }
            let list = try JSONDecoder().decode(ListPayload.self, from: data)
            return .success(list.data.count)
        } catch {
            return .failure(error)
        }
    }
}
