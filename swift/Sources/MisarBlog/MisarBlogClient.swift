import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking

/// swift-corelibs-foundation has no async `data(for:)`, so this package did not
/// build on Linux — which is where CI runs. Bridging the completion-handler API
/// keeps the SDK one implementation on every platform.
extension URLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            task.resume()
        }
    }
}
#endif

// MARK: - Client

/// Client for the Misar.Blog developer API (`https://api.misar.io/blog/v1`).
///
/// Authenticate with a Misar.Blog developer key (`mbk_...`) or an OAuth 2.1
/// access token — both are sent as `Authorization: Bearer <key>`.
///
/// Every call performs up to ``maxRetries`` attempts with exponential back-off
/// (starting at 500 ms) on retryable HTTP statuses (429, 500, 502, 503, 504).
/// The final attempt is always sent and its response returned or thrown — the
/// back-off never swallows the last try.
///
/// The keyed developer surface is plain request/response JSON — every operation
/// is a single request. The API exposes no SSE endpoint that accepts an API key
/// (the streaming routes are cookie-session or MCP transport), so there is
/// nothing to stream here.
/// Rate limit: 100 requests/minute.
public final class MisarBlogClient {

    public let apiKey: String
    public let baseURL: String
    public let maxRetries: Int
    public let session: URLSession

    private static let retryableStatuses: Set<Int> = [429, 500, 502, 503, 504]

    public init(
        apiKey: String,
        baseURL: String = "https://api.misar.io/blog/v1",
        maxRetries: Int = 3,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.baseURL = trimmed
        self.maxRetries = max(1, maxRetries)
        self.session = session
    }

    // MARK: Core request

    internal func request(
        method: String,
        path: String,
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + path) else {
            throw MisarBlogError.networkError(message: "Invalid URL: \(baseURL + path)")
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: 30)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else if method == "POST" {
            urlRequest.httpBody = Data("{}".utf8)
        }

        var lastError: Error?

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delayNs = UInt64(500_000_000) * UInt64(1 << (attempt - 1))
                try await Task.sleep(nanoseconds: delayNs)
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: urlRequest)
            } catch {
                lastError = error
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                lastError = MisarBlogError.networkError(message: "Non-HTTP response")
                continue
            }

            let status = http.statusCode

            // A plan-limit 429 is not "slow down": retrying cannot help until
            // the allowance resets or the plan changes, so surface it
            // immediately instead of burning the retry budget.
            if Self.isPlanLimit(data) {
                throw Self.parsePlanLimit(status: status, data: data, response: http)
            }

            // Retry retryable statuses — but only while attempts remain. On the
            // final attempt we fall through and surface the real response.
            if Self.retryableStatuses.contains(status) && attempt < maxRetries - 1 {
                lastError = MisarBlogError.apiError(status: status, message: "retryable")
                continue
            }

            if (200..<300).contains(status) {
                if data.isEmpty { return [:] }
                guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return [:]
                }
                return parsed
            }

            throw parseError(status: status, data: data)
        }

        throw MisarBlogError.networkError(message: "max retries exceeded: \(lastError?.localizedDescription ?? "unknown")")
    }

    /// True when an error body carries the API's plan-limit code.
    private static func isPlanLimit(_ data: Data) -> Bool {
        guard !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return obj["code"] as? String == "plan_limit_exceeded"
    }

    private static func parsePlanLimit(
        status: Int,
        data: Data,
        response: HTTPURLResponse
    ) -> MisarBlogError {
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let offer = obj["upgrade"] as? [String: Any] ?? [:]

        // Headers are authoritative; fall back to the offer body when a proxy
        // has stripped them.
        let header = { (name: String) -> String? in
            response.value(forHTTPHeaderField: name)
        }
        let plan = header("X-Misar-Plan")
            ?? (offer["current_plan"] as? [String: Any])?["slug"] as? String
        let upgradeURL = header("X-Misar-Upgrade-Url")
            ?? (offer["urls"] as? [String: Any])?["pricing"] as? String
        let retryAfter = header("Retry-After").flatMap(Int.init)

        return .planLimitExceeded(
            status: status,
            message: obj["error"] as? String ?? "plan limit exceeded",
            plan: plan,
            upgradeURL: upgradeURL,
            retryAfter: retryAfter
        )
    }

    private func parseError(status: Int, data: Data) -> MisarBlogError {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8) ?? "error"
            return .apiError(status: status, message: raw)
        }
        let message = (obj["error"] as? String)
            ?? (obj["message"] as? String)
            ?? (String(data: data, encoding: .utf8) ?? "error")
        let requiredScope = obj["required_scope"] as? String
        let grantedScopes = obj["granted_scopes"] as? [String] ?? []
        return .apiError(status: status, message: message, requiredScope: requiredScope, grantedScopes: grantedScopes)
    }

    /// Percent-encode a value for use as a single path segment.
    ///
    /// Query values were encoded but path segments were interpolated raw, so a
    /// slug containing a space produced an invalid URL and the request failed
    /// before it was sent. Only unreserved characters are kept, so a `/` cannot
    /// change the shape of the path either.
    internal static func segment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: Query helper

    /// Build a `?a=b&c=d` string from name/value pairs, dropping nil values and
    /// percent-encoding both sides. Returns "" when nothing is set.
    internal static func query(_ pairs: [(String, String?)]) -> String {
        let items = pairs.compactMap { name, value -> String? in
            guard let value = value else { return nil }
            let allowed = CharacterSet.urlQueryAllowed
            let n = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(n)=\(v)"
        }
        return items.isEmpty ? "" : "?" + items.joined(separator: "&")
    }

    // MARK: - Resource accessors

    public var ai:              AIResource { AIResource(client: self) }
    public var articles:        ArticlesResource { ArticlesResource(client: self) }
    public var images:          ImagesResource { ImagesResource(client: self) }
    public var profile:         ProfileResource { ProfileResource(client: self) }
    public var plan:            PlanResource { PlanResource(client: self) }
    public var reactions:       ReactionsResource { ReactionsResource(client: self) }
    public var recommendations: RecommendationsResource { RecommendationsResource(client: self) }
    public var search:          SearchResource { SearchResource(client: self) }
    public var series:          SeriesResource { SeriesResource(client: self) }
    public var trial:           TrialResource { TrialResource(client: self) }
    public var analytics:       AnalyticsResource { AnalyticsResource(client: self) }
    public var upsell:          UpsellResource { UpsellResource(client: self) }
    public var comments:        CommentsResource { CommentsResource(client: self) }
    public var follows:         FollowsResource { FollowsResource(client: self) }
}

// MARK: - AIResource

public class AIResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// POST /ai/complete — freeform completion.
    public func complete(prompt: String, system: String? = nil, maxTokens: Int? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["prompt": prompt]
        if let system = system { body["system"] = system }
        if let maxTokens = maxTokens { body["max_tokens"] = maxTokens }
        return try await client.request(method: "POST", path: "/ai/complete", body: body)
    }

    /// POST /ai/titles — SEO title / headline generation.
    public func titles(action: String, prompt: String? = nil, context: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["action": action]
        if let prompt = prompt { body["prompt"] = prompt }
        if let context = context { body["context"] = context }
        return try await client.request(method: "POST", path: "/ai/titles", body: body)
    }
}

// MARK: - ArticlesResource

public class ArticlesResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /articles — list the caller's articles.
    public func list(
        status: String? = nil,
        visibility: String? = nil,
        webhookOnly: String? = nil,
        sort: String? = nil,
        limit: Int? = nil
    ) async throws -> [String: Any] {
        let pairs: [(String, String?)] = [
            ("status", status),
            ("visibility", visibility),
            ("webhook_only", webhookOnly),
            ("sort", sort),
            ("limit", limit.map { "\($0)" }),
        ]
        let qs = MisarBlogClient.query(pairs)
        return try await client.request(method: "GET", path: "/articles\(qs)")
    }

    /// GET /articles/{slug} — fetch a single article.
    public func get(slug: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/articles/\(MisarBlogClient.segment(slug))")
    }

    /// PATCH /articles/{slug} — update title/body/tags or publish.
    /// `data` accepts: `title`, `body_markdown`, `tags`, `publish`.
    public func update(slug: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/articles/\(MisarBlogClient.segment(slug))", body: data)
    }

    /// POST /articles — publish (or schedule) a new article.
    /// `data` requires `title` + `body_markdown`; optional `tags`,
    /// `cover_image_url`, `schedule_at`, `visibility`.
    public func publish(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/articles", body: data)
    }

    /// POST /drafts — create an unpublished draft.
    /// `data` requires `title` + `body_markdown`; optional `tags`.
    public func createDraft(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/drafts", body: data)
    }
}

// MARK: - ImagesResource

public class ImagesResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// POST /images/generate — AI cover-image generation.
    public func generate(prompt: String, size: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["prompt": prompt]
        if let size = size { body["size"] = size }
        return try await client.request(method: "POST", path: "/images/generate", body: body)
    }

    /// POST /images/upload — register/upload an image asset.
    public func upload(data: [String: Any] = [:]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/images/upload", body: data)
    }
}

// MARK: - ProfileResource

public class ProfileResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /me — the authenticated author's profile.
    public func get() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/me")
    }
}

// MARK: - PlanResource

public class PlanResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /plan — current subscription plan + limits.
    public func get() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/plan")
    }
}

// MARK: - ReactionsResource

public class ReactionsResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /reactions — reaction counts for an article.
    public func get(articleId: String) async throws -> [String: Any] {
        let qs = MisarBlogClient.query([("article_id", articleId)])
        return try await client.request(method: "GET", path: "/reactions\(qs)")
    }

    /// POST /reactions — add a reaction.
    public func add(articleId: String, type: String) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/reactions", body: ["article_id": articleId, "type": type])
    }

    /// DELETE /reactions — remove a reaction.
    public func remove(articleId: String, type: String) async throws -> [String: Any] {
        let qs = MisarBlogClient.query([("article_id", articleId), ("type", type)])
        return try await client.request(method: "DELETE", path: "/reactions\(qs)")
    }
}

// MARK: - RecommendationsResource

public class RecommendationsResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /recommendations — related articles for a given article.
    public func get(articleId: String, limit: Int? = nil) async throws -> [String: Any] {
        let qs = MisarBlogClient.query([("article_id", articleId), ("limit", limit.map { "\($0)" })])
        return try await client.request(method: "GET", path: "/recommendations\(qs)")
    }
}

// MARK: - SearchResource

public class SearchResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /search — full-text article search with filters.
    public func query(
        q: String? = nil,
        type: String? = nil,
        tag: String? = nil,
        author: String? = nil,
        sort: String? = nil,
        from: String? = nil,
        to: String? = nil,
        limit: Int? = nil
    ) async throws -> [String: Any] {
        let pairs: [(String, String?)] = [
            ("q", q),
            ("type", type),
            ("tag", tag),
            ("author", author),
            ("sort", sort),
            ("from", from),
            ("to", to),
            ("limit", limit.map { "\($0)" }),
        ]
        let qs = MisarBlogClient.query(pairs)
        return try await client.request(method: "GET", path: "/search\(qs)")
    }
}

// MARK: - SeriesResource

public class SeriesResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /series — list the caller's series.
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/series")
    }

    /// POST /series — create a new series.
    public func create(title: String, description: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["title": title]
        if let description = description { body["description"] = description }
        return try await client.request(method: "POST", path: "/series", body: body)
    }

    /// POST /series/{slug}/articles — add an article to a series.
    public func addArticle(slug: String, articleSlug: String, position: Int? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["article_slug": articleSlug]
        if let position = position { body["position"] = position }
        return try await client.request(method: "POST", path: "/series/\(MisarBlogClient.segment(slug))/articles", body: body)
    }
}

// MARK: - TrialResource

public class TrialResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /trial — trial eligibility/status.
    public func status() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/trial")
    }

    /// POST /trial — start a trial for a feature.
    public func start(feature: String? = nil, ref: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let feature = feature { body["feature"] = feature }
        if let ref = ref { body["ref"] = ref }
        return try await client.request(method: "POST", path: "/trial", body: body)
    }
}

// MARK: - AnalyticsResource

public class AnalyticsResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /analytics — author analytics summary over a window of days.
    public func get(days: Int? = nil) async throws -> [String: Any] {
        let qs = MisarBlogClient.query([("days", days.map { "\($0)" })])
        return try await client.request(method: "GET", path: "/analytics\(qs)")
    }
}

// MARK: - UpsellResource

public class UpsellResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// GET /upsell-funnel — upsell/conversion funnel metrics.
    public func funnel(days: Int? = nil, feature: String? = nil) async throws -> [String: Any] {
        let qs = MisarBlogClient.query([("days", days.map { "\($0)" }), ("feature", feature)])
        return try await client.request(method: "GET", path: "/upsell-funnel\(qs)")
    }
}

// MARK: - CommentsResource

/// `GET /comments` — an article's comment thread.
public class CommentsResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// List an article's comments, newest first, replies nested one level deep.
    /// `limit` defaults to 20 (max 100) and `offset` to 0 server-side.
    public func list(
        articleID: String,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [String: Any] {
        let q = MisarBlogClient.query([
            ("article_id", articleID),
            ("limit", limit.map(String.init)),
            ("offset", offset.map(String.init)),
        ])
        return try await client.request(method: "GET", path: "/comments" + q)
    }
}

// MARK: - FollowsResource

/// `GET /follows` — follower counts and the caller's follow state.
public class FollowsResource {
    private let client: MisarBlogClient
    init(client: MisarBlogClient) { self.client = client }

    /// Follower/following counts for a profile, plus whether the key's owner
    /// follows it.
    public func status(userID: String) async throws -> [String: Any] {
        let q = MisarBlogClient.query([("user_id", userID)])
        return try await client.request(method: "GET", path: "/follows" + q)
    }
}
