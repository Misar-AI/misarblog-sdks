using System.Net;
using System.Text;
using MisarBlog;
using Xunit;

namespace MisarBlog.Tests;

/// <summary>
/// Unit tests for <see cref="MisarBlogClient"/>.
///
/// A stub <see cref="HttpMessageHandler"/> replaces the transport, so the real
/// request/retry/error code runs with no network call. This SDK had 28 compile
/// errors and no tests at all, so these start with the basics: that it builds
/// the URLs it claims to, and that a refusal is typed.
/// </summary>
public sealed class MisarBlogClientTests
{
    /// <summary>Replays a queue of responses and records what was asked for.</summary>
    private sealed class ScriptedHandler : HttpMessageHandler
    {
        private readonly Queue<(int Status, string Body, (string, string)[] Headers)> _queue;

        public List<string> Requests { get; } = new();

        public ScriptedHandler(params (int Status, string Body, (string, string)[] Headers)[] responses)
            => _queue = new(responses);

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request.RequestUri!.PathAndQuery);

            var (status, body, headers) = _queue.Count > 0
                ? _queue.Dequeue()
                : (500, "{\"error\":\"script exhausted\"}", Array.Empty<(string, string)>());

            var response = new HttpResponseMessage((HttpStatusCode)status)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            };
            foreach (var (name, value) in headers)
                response.Headers.TryAddWithoutValidation(name, value);

            return Task.FromResult(response);
        }
    }

    private static MisarBlogClient ClientWith(ScriptedHandler handler, int maxRetries = 1) =>
        new("mbk_test", maxRetries: maxRetries, httpClient: new HttpClient(handler));

    private static ScriptedHandler Ok(string body) =>
        new((200, body, Array.Empty<(string, string)>()));

    // ── Construction ─────────────────────────────────────────────────────────

    [Fact]
    public void BlankApiKeyIsRejected()
    {
        // Failing at construction beats a 401 on the first call.
        Assert.Throws<ArgumentException>(() => new MisarBlogClient("  "));
    }

    // ── REST ─────────────────────────────────────────────────────────────────

    [Fact]
    public async Task ArticlesList_ReturnsParsedBody()
    {
        var handler = Ok("{\"articles\":[{\"slug\":\"hello\"}],\"total\":1}");
        var result = await ClientWith(handler).Articles_ListAsync(limit: 10);

        Assert.Equal(1, result.GetProperty("total").GetInt32());
        Assert.Equal("hello", result.GetProperty("articles")[0].GetProperty("slug").GetString());
        // The limit must reach the wire, not merely the signature.
        Assert.Contains("limit=10", handler.Requests[0]);
    }

    [Fact]
    public async Task ArticlesList_OmitsUnsetQueryParameters()
    {
        var handler = Ok("{\"articles\":[],\"total\":0}");
        await ClientWith(handler).Articles_ListAsync();

        // A bare path, not "?status=&visibility=" — empty values would be sent
        // to the server as real filters.
        Assert.Equal("/blog/v1/articles", handler.Requests[0]);
    }

    [Fact]
    public async Task ProfileGet_ReturnsTheAccount()
    {
        var result = await ClientWith(Ok("{\"id\":\"u1\",\"username\":\"gulshan\"}")).Profile_GetAsync();

        Assert.Equal("gulshan", result.GetProperty("username").GetString());
    }

    [Fact]
    public async Task PlanGet_ReportsTheSubscriptionBehindTheKey()
    {
        var result = await ClientWith(Ok("{\"plan\":{\"slug\":\"pro\"}}")).Plan_GetAsync();

        Assert.Equal("pro", result.GetProperty("plan").GetProperty("slug").GetString());
    }

    [Fact]
    public async Task CommentsList_PassesTheArticleIdAsAQueryParameter()
    {
        // comments and follows were added late and are query-filtered rather than
        // path-scoped; this pins that shape.
        var handler = Ok("{\"comments\":[],\"total\":0}");
        await ClientWith(handler).Comments_ListAsync("a1");

        Assert.Contains("/blog/v1/comments", handler.Requests[0]);
        Assert.Contains("article_id=a1", handler.Requests[0]);
    }

    [Fact]
    public async Task FollowsStatus_PassesTheUserId()
    {
        var handler = Ok("{\"following\":true}");
        await ClientWith(handler).Follows_StatusAsync("u2");

        Assert.Contains("user_id=u2", handler.Requests[0]);
    }

    // ── Errors ───────────────────────────────────────────────────────────────

    [Fact]
    public async Task Unauthorized_ThrowsWithStatus()
    {
        var handler = new ScriptedHandler((401, "{\"error\":\"unauthorized\"}", Array.Empty<(string, string)>()));
        var ex = await Assert.ThrowsAsync<MisarBlogException>(
            () => ClientWith(handler).Profile_GetAsync());

        Assert.Equal(401, ex.Status);
    }

    [Fact]
    public async Task InsufficientScope_CarriesTheScopeDetail()
    {
        // A 403 that names the missing scope is actionable; a bare "forbidden" is not.
        var handler = new ScriptedHandler((403,
            "{\"error\":\"insufficient scope\",\"required_scope\":\"articles:write\"," +
            "\"granted_scopes\":[\"articles:read\"]}", Array.Empty<(string, string)>()));

        var ex = await Assert.ThrowsAsync<MisarBlogException>(
            () => ClientWith(handler).Articles_PublishAsync(new { title = "x" }));

        Assert.Equal(403, ex.Status);
        Assert.Equal("articles:write", ex.RequiredScope);
        Assert.Contains("articles:read", ex.GrantedScopes);
    }

    [Fact]
    public async Task SpentAllowance_ThrowsPlanLimitAndIsNotRetried()
    {
        const string body = """
        {"code":"plan_limit_exceeded","error":"monthly article allowance spent",
         "upgrade":{"urls":{"pricing":"https://www.misar.blog/pricing"}}}
        """;
        var handler = new ScriptedHandler(
            (429, body, new[] { ("X-Misar-Plan", "starter"), ("Retry-After", "3600") }));

        // maxRetries 3, so a plain retryable 429 would have been retried twice more.
        var ex = await Assert.ThrowsAsync<MisarBlogPlanLimitException>(
            () => ClientWith(handler, maxRetries: 3).Articles_PublishAsync(new { title = "x" }));

        Assert.Equal(429, ex.Status);
        Assert.Equal("starter", ex.Plan);
        Assert.Equal(3600, ex.RetryAfter);
        Assert.Equal("https://www.misar.blog/pricing", ex.UpgradeUrl);

        // A spent allowance cannot be fixed by retrying.
        Assert.Single(handler.Requests);
    }

    [Fact]
    public async Task Retries503ThenSucceeds()
    {
        var handler = new ScriptedHandler(
            (503, "{\"error\":\"unavailable\"}", Array.Empty<(string, string)>()),
            (503, "{\"error\":\"unavailable\"}", Array.Empty<(string, string)>()),
            (200, "{\"articles\":[],\"total\":0}", Array.Empty<(string, string)>()));

        var result = await ClientWith(handler, maxRetries: 3).Articles_ListAsync();

        Assert.Equal(0, result.GetProperty("total").GetInt32());
        Assert.Equal(3, handler.Requests.Count);
    }
}
