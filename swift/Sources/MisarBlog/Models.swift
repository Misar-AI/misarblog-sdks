import Foundation

// URLSession, URLRequest and HTTPURLResponse live in FoundationNetworking on
// Linux rather than Foundation.
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Typed models
//
// The dev API returns plain JSON. Resource methods hand back the decoded
// `[String: Any]` payload (uniform, forward-compatible). These `Codable`
// value types mirror the OpenAPI component schemas so callers that prefer a
// typed view can decode with ``Article/from(_:)`` / ``Series/from(_:)``.

/// A blog article, per the `Article` schema.
public struct Article: Codable, Equatable {
    public let id: String?
    public let slug: String?
    public let title: String?
    public let status: String?
    public let url: String?
    public let editorURL: String?
    public let excerpt: String?
    public let tags: [String]?
    public let visibility: String?
    public let publishedAt: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, status, url, excerpt, tags, visibility
        case editorURL = "editor_url"
        case publishedAt = "published_at"
        case createdAt = "created_at"
    }

    /// Decode an ``Article`` from a raw JSON dictionary (e.g. a resource result).
    public static func from(_ json: [String: Any]) throws -> Article {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Article.self, from: data)
    }
}

/// A series/collection of articles, per the `Series` schema.
public struct Series: Codable, Equatable {
    public let id: String?
    public let slug: String?
    public let title: String?
    public let description: String?
    public let articleCount: Int?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description
        case articleCount = "article_count"
        case createdAt = "created_at"
    }

    /// Decode a ``Series`` from a raw JSON dictionary.
    public static func from(_ json: [String: Any]) throws -> Series {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Series.self, from: data)
    }
}
