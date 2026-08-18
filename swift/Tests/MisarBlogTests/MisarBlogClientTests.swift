import XCTest
@testable import MisarBlog

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Intercepts requests and replays a scripted response.
final class StubURLProtocol: URLProtocol {
    struct Stub {
        var status: Int = 200
        var headers: [String: String] = ["Content-Type": "application/json"]
        var body: String = "{}"
    }

    static var stubs: [String: Stub] = [:]
    static var requestedPaths: [String] = []
    static var requestedQueries: [String] = []
    /// Absolute strings, because `url.path` is decoded and cannot show encoding.
    static var requestedURLs: [String] = []

    static func reset() {
        stubs = [:]
        requestedPaths = []
        requestedQueries = []
        requestedURLs = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        StubURLProtocol.requestedPaths.append(path)
        StubURLProtocol.requestedQueries.append(request.url?.query ?? "")
        StubURLProtocol.requestedURLs.append(request.url?.absoluteString ?? "")

        let stub = StubURLProtocol.stubs[path]
            ?? .init(status: 404, body: #"{"error":"no stub"}"#)

        let response = HTTPURLResponse(
            url: request.url!, statusCode: stub.status,
            httpVersion: "HTTP/1.1", headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class MisarBlogClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func client(maxRetries: Int = 1) -> MisarBlogClient {
        MisarBlogClient(apiKey: "mbk_test", maxRetries: maxRetries, session: makeSession())
    }

    private func stub(_ path: String, status: Int = 200,
                      headers: [String: String] = [:], _ body: String) {
        var merged = ["Content-Type": "application/json"]
        headers.forEach { merged[$0.key] = $0.value }
        StubURLProtocol.stubs[path] = .init(status: status, headers: merged, body: body)
    }

    // MARK: Ownership

    func testResourcesKeepTheClientAlive() async throws {
        stub("/blog/v1/articles", #"{"articles":[],"total":0}"#)

        // Constructed inline, so nothing else holds a reference. While resources
        // were `lazy var` holding the client `unowned`, this crashed reading a
        // deallocated object — a shape any caller might reasonably write.
        let result = try await MisarBlogClient(
            apiKey: "mbk_test", maxRetries: 1, session: makeSession()
        ).articles.list()

        XCTAssertEqual(result["total"] as? Int, 0)
    }

    // MARK: REST

    func testArticlesListReturnsParsedBody() async throws {
        stub("/blog/v1/articles",
             #"{"articles":[{"slug":"hello","title":"Hello"}],"total":1}"#)

        let result = try await client().articles.list(limit: 10)
        let articles = result["articles"] as? [[String: Any]]

        XCTAssertEqual(result["total"] as? Int, 1)
        XCTAssertEqual(articles?.first?["slug"] as? String, "hello")
        // The limit must reach the wire, not just the signature.
        XCTAssertTrue(StubURLProtocol.requestedQueries.first?.contains("limit=10") ?? false,
                      StubURLProtocol.requestedQueries.description)
    }

    func testArticlesGetEncodesTheSlug() async throws {
        // Keyed on the decoded path, since that is what url.path reports.
        stub("/blog/v1/articles/a b", #"{"slug":"a b"}"#)

        _ = try await client().articles.get(slug: "a b")

        // Interpolated raw, a space made the URL invalid and nothing was sent at
        // all. The encoded form is what actually goes on the wire.
        XCTAssertEqual(StubURLProtocol.requestedURLs.first,
                       "https://api.misar.io/blog/v1/articles/a%20b")
        XCTAssertEqual(StubURLProtocol.requestedPaths.first, "/blog/v1/articles/a b")
    }

    func testProfileSendsTheBearerToken() async throws {
        stub("/blog/v1/me", #"{"id":"u1","username":"gulshan"}"#)

        let result = try await client().profile.get()

        XCTAssertEqual(result["username"] as? String, "gulshan")
    }

    func testPlanReportsTheSubscriptionBehindTheKey() async throws {
        stub("/blog/v1/plan", #"{"plan":{"slug":"pro"},"limits":{"articles_per_month":100}}"#)

        let result = try await client().plan.get()
        let plan = result["plan"] as? [String: Any]

        XCTAssertEqual(plan?["slug"] as? String, "pro")
    }

    func testCommentsListIsReachable() async throws {
        // comments and follows were added late; this pins that they are wired to
        // the client rather than merely declared.
        stub("/blog/v1/comments", #"{"comments":[{"id":"c1"}],"total":1}"#)

        let result = try await client().comments.list(articleID: "a1")

        XCTAssertEqual(result["total"] as? Int, 1)
    }

    // MARK: Errors

    func testUnauthorizedThrowsApiErrorWithStatus() async throws {
        stub("/blog/v1/me", status: 401, #"{"error":"unauthorized"}"#)

        do {
            _ = try await client().profile.get()
            XCTFail("expected an error")
        } catch let error as MisarBlogError {
            guard case let .apiError(status, _, _, _) = error else {
                return XCTFail("expected apiError, got \(error)")
            }
            XCTAssertEqual(status, 401)
        }
    }

    func testSpentAllowanceThrowsPlanLimitAndIsNotRetried() async throws {
        stub("/blog/v1/articles", status: 429,
             headers: ["X-Misar-Plan": "starter", "Retry-After": "3600"],
             """
             {"code":"plan_limit_exceeded","error":"monthly article allowance spent",
              "upgrade":{"urls":{"pricing":"https://www.misar.blog/pricing"}}}
             """)

        // maxRetries 3, so a plain retryable 429 would have been retried twice more.
        do {
            _ = try await client(maxRetries: 3).articles.publish(data: ["title": "x"])
            XCTFail("expected a plan-limit error")
        } catch let error as MisarBlogError {
            guard case let .planLimitExceeded(status, _, plan, upgradeURL, retryAfter) = error else {
                return XCTFail("expected planLimitExceeded, got \(error)")
            }
            XCTAssertEqual(status, 429)
            XCTAssertEqual(plan, "starter")
            XCTAssertEqual(retryAfter, 3600)
            XCTAssertEqual(upgradeURL, "https://www.misar.blog/pricing")
        }

        // A spent allowance cannot be fixed by retrying.
        XCTAssertEqual(StubURLProtocol.requestedPaths.count, 1)
    }

    func testUpgradeURLIsExposedOnTheError() async throws {
        stub("/blog/v1/articles", status: 402,
             """
             {"code":"plan_limit_exceeded","error":"not on your plan",
              "upgrade":{"urls":{"pricing":"https://www.misar.blog/pricing"}}}
             """)

        do {
            _ = try await client().articles.publish(data: [:])
            XCTFail("expected a plan-limit error")
        } catch let error as MisarBlogError {
            // The convenience accessor is what a caller reaches for.
            XCTAssertEqual(error.upgradeURL, "https://www.misar.blog/pricing")
        }
    }

    // MARK: Embed helper

    func testEmbedURLBuildsBothShapes() {
        // Unauthenticated and independent of the API client.
        let embed = MisarBlog()

        XCTAssertEqual(embed.embedURL(username: "gulshan", theme: "dark").absoluteString,
                       "https://misar.blog/gulshan/embed?theme=dark")
        XCTAssertEqual(embed.embedURL(username: "gulshan", slug: "hello", theme: "light").absoluteString,
                       "https://misar.blog/gulshan/hello/embed?theme=light")
        // "auto" is the default and deliberately omits the parameter, letting the
        // embed follow the host page rather than pinning a theme.
        XCTAssertEqual(embed.embedURL(username: "gulshan").absoluteString,
                       "https://misar.blog/gulshan/embed")
    }
}
