using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace MisarBlog;

/// <summary>
/// Client for the Misar.Blog developer API (<c>https://api.misar.io/blog/v1</c>).
///
/// Authenticate with a Misar.Blog developer key (<c>mbk_...</c>) or an OAuth 2.1
/// access token — both go on <c>Authorization: Bearer &lt;key&gt;</c>.
///
/// Every call performs up to <see cref="MaxRetries"/> attempts with exponential
/// back-off (starting at 500 ms) on retryable HTTP statuses (429, 500, 502, 503,
/// 504). The final attempt is always sent and its response returned/thrown.
///
/// Plain request/response JSON — every operation on the keyed developer surface
/// is a single request. The API exposes no SSE endpoint that accepts an API key
/// (the streaming routes are cookie-session or MCP transport), so there is
/// nothing to stream here. Rate limit:
/// 100 requests/minute.
/// </summary>
public sealed class MisarBlogClient : IDisposable
{
    private static readonly HashSet<int> RetryableStatuses = [429, 500, 502, 503, 504];

    private readonly string _apiKey;
    private readonly string _baseUrl;
    private readonly int _maxRetries;
    private readonly HttpClient _httpClient;
    private readonly bool _ownsHttpClient;

    public int MaxRetries => _maxRetries;

    public MisarBlogClient(
        string apiKey,
        string baseUrl = "https://api.misar.io/blog/v1",
        int maxRetries = 3,
        HttpClient? httpClient = null)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new ArgumentException("apiKey must not be blank.", nameof(apiKey));

        _apiKey = apiKey;
        _baseUrl = baseUrl.TrimEnd('/');
        _maxRetries = Math.Max(1, maxRetries);
        _ownsHttpClient = httpClient is null;
        _httpClient = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    }

    // -------------------------------------------------------------------------
    // Core request logic
    // -------------------------------------------------------------------------

    private async Task<JsonElement> RequestAsync(
        HttpMethod method,
        string path,
        object? body = null,
        // Named `ct` because all 14 call sites pass `ct:`; the mismatch meant
        // this SDK had never compiled.
        CancellationToken ct = default)
    {
        string url = _baseUrl + path;
        string? bodyJson = body is not null
            ? JsonSerializer.Serialize(body)
            : method == HttpMethod.Post ? "{}" : null;

        Exception? lastException = null;

        for (int attempt = 0; attempt < _maxRetries; attempt++)
        {
            if (attempt > 0)
            {
                int delayMs = 500 * (1 << (attempt - 1));
                await Task.Delay(delayMs, ct).ConfigureAwait(false);
            }

            using var request = new HttpRequestMessage(method, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            if (bodyJson is not null)
                request.Content = new StringContent(bodyJson, Encoding.UTF8, "application/json");

            HttpResponseMessage response;
            try
            {
                response = await _httpClient.SendAsync(request, ct).ConfigureAwait(false);
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
            {
                lastException = ex;
                continue;
            }

            using (response)
            {
                int status = (int)response.StatusCode;

                string responseBody = await response.Content
                    .ReadAsStringAsync(ct).ConfigureAwait(false);

                // A plan-limit 429 is not "slow down": retrying cannot help
                // until the allowance resets or the plan changes, so surface it
                // immediately instead of burning the retry budget.
                if (IsPlanLimit(responseBody))
                    throw BuildPlanLimitError(status, responseBody, response);

                // Retry retryable statuses only while attempts remain; the final
                // attempt falls through and surfaces the real response.
                if (RetryableStatuses.Contains(status) && attempt < _maxRetries - 1)
                {
                    lastException = new MisarBlogException(status, "retryable error");
                    continue;
                }

                if (response.IsSuccessStatusCode)
                {
                    if (string.IsNullOrWhiteSpace(responseBody))
                        return JsonDocument.Parse("{}").RootElement.Clone();
                    using var doc = JsonDocument.Parse(responseBody);
                    return doc.RootElement.Clone();
                }

                throw BuildError(status, responseBody);
            }
        }

        throw new MisarBlogNetworkException($"max retries exceeded: {lastException?.Message ?? "unknown"}");
    }

    /// <summary>True when an error body carries the API's plan-limit code.</summary>
    private static bool IsPlanLimit(string body)
    {
        if (string.IsNullOrWhiteSpace(body)) return false;
        try
        {
            using var doc = JsonDocument.Parse(body);
            return doc.RootElement.TryGetProperty("code", out var code)
                && code.ValueKind == JsonValueKind.String
                && code.GetString() == "plan_limit_exceeded";
        }
        catch { return false; }
    }

    private static MisarBlogPlanLimitException BuildPlanLimitError(
        int status, string body, HttpResponseMessage response)
    {
        string message = "plan limit exceeded";
        string? plan = null, upgradeUrl = null;

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.TryGetProperty("error", out var err) && err.ValueKind == JsonValueKind.String)
                message = err.GetString() ?? message;

            // Headers are authoritative; fall back to the offer body when a
            // proxy has stripped them.
            if (root.TryGetProperty("upgrade", out var offer) && offer.ValueKind == JsonValueKind.Object)
            {
                if (offer.TryGetProperty("urls", out var urls)
                    && urls.TryGetProperty("pricing", out var pricing)
                    && pricing.ValueKind == JsonValueKind.String)
                    upgradeUrl = pricing.GetString();

                if (offer.TryGetProperty("current_plan", out var cp)
                    && cp.TryGetProperty("slug", out var slug)
                    && slug.ValueKind == JsonValueKind.String)
                    plan = slug.GetString();
            }
        }
        catch { /* non-JSON body — keep defaults */ }

        if (response.Headers.TryGetValues("X-Misar-Plan", out var planHeader))
            plan = System.Linq.Enumerable.FirstOrDefault(planHeader) ?? plan;
        if (response.Headers.TryGetValues("X-Misar-Upgrade-Url", out var urlHeader))
            upgradeUrl = System.Linq.Enumerable.FirstOrDefault(urlHeader) ?? upgradeUrl;

        int? retryAfter = null;
        if (response.Headers.TryGetValues("Retry-After", out var ra)
            && int.TryParse(System.Linq.Enumerable.FirstOrDefault(ra), out var seconds))
            retryAfter = seconds;

        return new MisarBlogPlanLimitException(status, message, plan, upgradeUrl, retryAfter);
    }

    private static MisarBlogException BuildError(int status, string body)
    {
        string message = string.IsNullOrWhiteSpace(body) ? "error" : body;
        string? requiredScope = null;
        List<string>? grantedScopes = null;

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.TryGetProperty("error", out var err) && err.ValueKind == JsonValueKind.String)
                message = err.GetString() ?? message;
            else if (root.TryGetProperty("message", out var msg) && msg.ValueKind == JsonValueKind.String)
                message = msg.GetString() ?? message;

            if (root.TryGetProperty("required_scope", out var rs) && rs.ValueKind == JsonValueKind.String)
                requiredScope = rs.GetString();

            if (root.TryGetProperty("granted_scopes", out var gs) && gs.ValueKind == JsonValueKind.Array)
            {
                grantedScopes = new List<string>();
                foreach (var item in gs.EnumerateArray())
                    if (item.ValueKind == JsonValueKind.String)
                        grantedScopes.Add(item.GetString()!);
            }
        }
        catch { /* non-JSON body — keep raw message */ }

        return new MisarBlogException(status, message, requiredScope, grantedScopes);
    }

    private static string BuildQuery(params (string Name, string? Value)[] pairs)
    {
        var parts = new List<string>();
        foreach (var (name, value) in pairs)
        {
            if (value is null) continue;
            parts.Add($"{WebUtility.UrlEncode(name)}={WebUtility.UrlEncode(value)}");
        }
        return parts.Count == 0 ? "" : "?" + string.Join("&", parts);
    }

    // =========================================================================
    // AI
    // =========================================================================

    /// <summary>POST /ai/complete</summary>
    public Task<JsonElement> Ai_CompleteAsync(string prompt, string? system = null, int? maxTokens = null, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["prompt"] = prompt };
        if (system is not null) body["system"] = system;
        if (maxTokens is not null) body["max_tokens"] = maxTokens;
        return RequestAsync(HttpMethod.Post, "/ai/complete", body, ct);
    }

    /// <summary>POST /ai/titles</summary>
    public Task<JsonElement> Ai_TitlesAsync(string action, string? prompt = null, string? context = null, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["action"] = action };
        if (prompt is not null) body["prompt"] = prompt;
        if (context is not null) body["context"] = context;
        return RequestAsync(HttpMethod.Post, "/ai/titles", body, ct);
    }

    // =========================================================================
    // Articles
    // =========================================================================

    /// <summary>GET /articles</summary>
    public Task<JsonElement> Articles_ListAsync(
        string? status = null, string? visibility = null, string? webhookOnly = null,
        string? sort = null, int? limit = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/articles" + BuildQuery(
            ("status", status), ("visibility", visibility), ("webhook_only", webhookOnly),
            ("sort", sort), ("limit", limit?.ToString())), ct: ct);

    /// <summary>GET /articles/{slug}</summary>
    public Task<JsonElement> Articles_GetAsync(string slug, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/articles/{slug}", ct: ct);

    /// <summary>PATCH /articles/{slug} — accepts title, body_markdown, tags, publish.</summary>
    public Task<JsonElement> Articles_UpdateAsync(string slug, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/articles/{slug}", payload, ct);

    /// <summary>POST /articles — requires title + body_markdown.</summary>
    public Task<JsonElement> Articles_PublishAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/articles", payload, ct);

    /// <summary>POST /drafts — requires title + body_markdown.</summary>
    public Task<JsonElement> Articles_CreateDraftAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/drafts", payload, ct);

    // =========================================================================
    // Images
    // =========================================================================

    /// <summary>POST /images/generate</summary>
    public Task<JsonElement> Images_GenerateAsync(string prompt, string? size = null, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["prompt"] = prompt };
        if (size is not null) body["size"] = size;
        return RequestAsync(HttpMethod.Post, "/images/generate", body, ct);
    }

    /// <summary>POST /images/upload</summary>
    public Task<JsonElement> Images_UploadAsync(object? payload = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/images/upload", payload, ct);

    // =========================================================================
    // Profile / Plan
    // =========================================================================

    /// <summary>GET /me</summary>
    public Task<JsonElement> Profile_GetAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/me", ct: ct);

    /// <summary>GET /plan</summary>
    public Task<JsonElement> Plan_GetAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/plan", ct: ct);

    // =========================================================================
    // Reactions
    // =========================================================================

    /// <summary>GET /reactions</summary>
    public Task<JsonElement> Reactions_GetAsync(string articleId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/reactions" + BuildQuery(("article_id", articleId)), ct: ct);

    /// <summary>POST /reactions</summary>
    public Task<JsonElement> Reactions_AddAsync(string articleId, string type, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/reactions", new { article_id = articleId, type }, ct);

    /// <summary>DELETE /reactions</summary>
    public Task<JsonElement> Reactions_RemoveAsync(string articleId, string type, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, "/reactions" + BuildQuery(("article_id", articleId), ("type", type)), ct: ct);

    // =========================================================================
    // Comments / Follows
    // =========================================================================

    /// <summary>
    /// GET /comments — an article's comment thread, newest first, replies
    /// nested one level deep. <paramref name="limit"/> defaults to 20 (max 100)
    /// and <paramref name="offset"/> to 0 server-side.
    /// </summary>
    public Task<JsonElement> Comments_ListAsync(string articleId, int? limit = null, int? offset = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/comments" + BuildQuery(("article_id", articleId), ("limit", limit?.ToString()), ("offset", offset?.ToString())), ct: ct);

    /// <summary>
    /// GET /follows — a profile's follower/following counts plus whether the
    /// key's owner follows it.
    /// </summary>
    public Task<JsonElement> Follows_StatusAsync(string userId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/follows" + BuildQuery(("user_id", userId)), ct: ct);

    // =========================================================================
    // Recommendations / Search
    // =========================================================================

    /// <summary>GET /recommendations</summary>
    public Task<JsonElement> Recommendations_GetAsync(string articleId, int? limit = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/recommendations" + BuildQuery(("article_id", articleId), ("limit", limit?.ToString())), ct: ct);

    /// <summary>GET /search</summary>
    public Task<JsonElement> SearchAsync(
        string? q = null, string? type = null, string? tag = null, string? author = null,
        string? sort = null, string? from = null, string? to = null, int? limit = null,
        CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/search" + BuildQuery(
            ("q", q), ("type", type), ("tag", tag), ("author", author),
            ("sort", sort), ("from", from), ("to", to), ("limit", limit?.ToString())), ct: ct);

    // =========================================================================
    // Series
    // =========================================================================

    /// <summary>GET /series</summary>
    public Task<JsonElement> Series_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/series", ct: ct);

    /// <summary>POST /series</summary>
    public Task<JsonElement> Series_CreateAsync(string title, string? description = null, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["title"] = title };
        if (description is not null) body["description"] = description;
        return RequestAsync(HttpMethod.Post, "/series", body, ct);
    }

    /// <summary>POST /series/{slug}/articles</summary>
    public Task<JsonElement> Series_AddArticleAsync(string slug, string articleSlug, int? position = null, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["article_slug"] = articleSlug };
        if (position is not null) body["position"] = position;
        return RequestAsync(HttpMethod.Post, $"/series/{slug}/articles", body, ct);
    }

    // =========================================================================
    // Trial
    // =========================================================================

    /// <summary>GET /trial</summary>
    public Task<JsonElement> Trial_StatusAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/trial", ct: ct);

    /// <summary>POST /trial</summary>
    public Task<JsonElement> Trial_StartAsync(string? feature = null, string? @ref = null, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object>();
        if (feature is not null) body["feature"] = feature;
        if (@ref is not null) body["ref"] = @ref;
        return RequestAsync(HttpMethod.Post, "/trial", body, ct);
    }

    // =========================================================================
    // Analytics / Upsell
    // =========================================================================

    /// <summary>GET /analytics</summary>
    public Task<JsonElement> Analytics_GetAsync(int? days = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/analytics" + BuildQuery(("days", days?.ToString())), ct: ct);

    /// <summary>GET /upsell-funnel</summary>
    public Task<JsonElement> Upsell_FunnelAsync(int? days = null, string? feature = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/upsell-funnel" + BuildQuery(("days", days?.ToString()), ("feature", feature)), ct: ct);

    // -------------------------------------------------------------------------
    // IDisposable
    // -------------------------------------------------------------------------

    public void Dispose()
    {
        if (_ownsHttpClient)
            _httpClient.Dispose();
    }
}
