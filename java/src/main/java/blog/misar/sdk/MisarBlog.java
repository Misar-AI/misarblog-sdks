package blog.misar.sdk;

import blog.misar.sdk.models.Article;
import blog.misar.sdk.models.Series;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.stream.Collectors;

/**
 * Client for the <b>Misar.Blog developer API</b> — full coverage of the 25
 * key-authenticated operations.
 *
 * <p>Authentication uses a developer key sent as {@code Authorization: Bearer mbk_...}
 * (OAuth 2.1 access tokens are accepted on the same header). The default base URL
 * is {@code https://api.misar.io/blog/v1} — the gateway strips {@code /api}.
 *
 * <p>All methods perform up to {@code maxRetries} attempts with exponential
 * back-off (starting at 500&nbsp;ms) on retryable HTTP statuses (429, 500, 502,
 * 503, 504) and network errors. The request is sent on every attempt including
 * the last one.
 *
 * <pre>{@code
 * MisarBlog blog = new MisarBlog.Builder("mbk_...").build();
 * Article a = blog.articles.publish(Map.of(
 *     "title", "Hello", "body_markdown", "# Hi"));
 * }</pre>
 */
public final class MisarBlog {

    private static final Set<Integer> RETRYABLE = Set.of(429, 500, 502, 503, 504);
    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(30);
    private static final String EMBED_BASE = "https://misar.blog";

    private final String apiKey;
    private final String baseUrl;
    private final int maxRetries;
    private final HttpClient http;
    private final ObjectMapper mapper = new ObjectMapper();

    // ── resource accessors ────────────────────────────────────────────────────
    public final ArticlesResource articles;
    public final SeriesResource series;
    public final ReactionsResource reactions;
    public final AiResource ai;
    public final ImagesResource images;
    public final AccountResource account;
    public final AnalyticsResource analytics;
    public final PlanResource plan;
    public final CommentsResource comments;
    public final FollowsResource follows;

    private MisarBlog(Builder b) {
        this.apiKey = b.apiKey;
        this.baseUrl = b.baseUrl.endsWith("/") ? b.baseUrl.substring(0, b.baseUrl.length() - 1) : b.baseUrl;
        this.maxRetries = Math.max(1, b.maxRetries);
        this.http = b.httpClient != null ? b.httpClient
                : HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();

        this.articles = new ArticlesResource();
        this.series = new SeriesResource();
        this.reactions = new ReactionsResource();
        this.ai = new AiResource();
        this.images = new ImagesResource();
        this.account = new AccountResource();
        this.analytics = new AnalyticsResource();
        this.plan = new PlanResource();
        this.comments = new CommentsResource();
        this.follows = new FollowsResource();
    }

    /** Convenience constructor with defaults. */
    public MisarBlog(String apiKey) {
        this(new Builder(apiKey));
    }

    // ── Builder ───────────────────────────────────────────────────────────────

    public static final class Builder {
        private final String apiKey;
        private String baseUrl = "https://api.misar.io/blog/v1";
        private int maxRetries = 3;
        private HttpClient httpClient;

        public Builder(String apiKey) {
            if (apiKey == null || apiKey.isBlank()) throw new IllegalArgumentException("apiKey must not be blank");
            this.apiKey = apiKey;
        }

        public Builder baseUrl(String baseUrl) { this.baseUrl = baseUrl; return this; }
        public Builder maxRetries(int maxRetries) { this.maxRetries = maxRetries; return this; }
        public Builder httpClient(HttpClient httpClient) { this.httpClient = httpClient; return this; }
        public MisarBlog build() { return new MisarBlog(this); }
    }

    // ── Core HTTP ─────────────────────────────────────────────────────────────

    private static String qs(Map<String, Object> params) {
        if (params == null || params.isEmpty()) return "";
        return "?" + params.entrySet().stream()
                .filter(e -> e.getValue() != null)
                .map(e -> enc(e.getKey()) + "=" + enc(String.valueOf(e.getValue())))
                .collect(Collectors.joining("&"));
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> request(String method, String path, Object body) throws BlogApiException {
        String url = baseUrl + path;
        String bodyStr;
        try {
            bodyStr = body != null ? mapper.writeValueAsString(body) : null;
        } catch (Exception e) {
            throw new BlogApiException(0, "Failed to serialize request body: " + e.getMessage(), e);
        }

        Exception last = null;
        for (int attempt = 0; attempt < maxRetries; attempt++) {
            if (attempt > 0) {
                try {
                    Thread.sleep(500L * (1L << (attempt - 1)));
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new BlogApiException(0, "Interrupted during retry back-off", ie);
                }
            }

            HttpRequest.Builder rb = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(REQUEST_TIMEOUT)
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json");

            HttpRequest.BodyPublisher bp = bodyStr != null
                    ? HttpRequest.BodyPublishers.ofString(bodyStr)
                    : HttpRequest.BodyPublishers.noBody();
            switch (method) {
                case "GET"    -> rb.GET();
                case "POST"   -> rb.POST(bp);
                case "PATCH"  -> rb.method("PATCH", bp);
                case "PUT"    -> rb.PUT(bp);
                case "DELETE" -> rb.method("DELETE", HttpRequest.BodyPublishers.noBody());
                default -> throw new IllegalArgumentException("Unsupported HTTP method: " + method);
            }

            HttpResponse<String> resp;
            try {
                resp = http.send(rb.build(), HttpResponse.BodyHandlers.ofString());
            } catch (IOException | InterruptedException e) {
                if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                last = e;
                continue; // retry (or exit loop -> "max retries exceeded")
            }

            int status = resp.statusCode();

            // A plan-limit 429 is not "slow down": retrying cannot help until
            // the allowance resets or the plan changes, so surface it
            // immediately instead of burning the retry budget.
            if (isPlanLimit(resp.body())) {
                throw planLimitException(status, resp);
            }

            // Retry only when attempts remain; the final attempt returns the real result.
            if (RETRYABLE.contains(status) && attempt < maxRetries - 1) {
                last = new BlogApiException(status, errorMessage(resp.body()));
                continue;
            }
            if (status >= 200 && status < 300) {
                String rbody = resp.body();
                if (rbody == null || rbody.isBlank()) return new HashMap<>();
                try {
                    return mapper.readValue(rbody, Map.class);
                } catch (Exception e) {
                    throw new BlogApiException(0, "Failed to parse response: " + e.getMessage(), e);
                }
            }
            throw new BlogApiException(status, errorMessage(resp.body()));
        }
        String cause = last != null ? last.getMessage() : "unknown";
        throw new BlogApiException(0, "Max retries exceeded: " + cause, last);
    }

    /** True when an error body carries the API's plan-limit code. */
    @SuppressWarnings("unchecked")
    private boolean isPlanLimit(String body) {
        if (body == null || body.isBlank()) return false;
        try {
            Object code = mapper.readValue(body, Map.class).get("code");
            return "plan_limit_exceeded".equals(code);
        } catch (Exception ignored) {
            return false;
        }
    }

    @SuppressWarnings("unchecked")
    private PlanLimitException planLimitException(int status, HttpResponse<String> resp) {
        String message = errorMessage(resp.body());
        String plan = null;
        String upgradeUrl = null;

        // Headers are authoritative; fall back to the offer body when a proxy
        // has stripped them.
        try {
            Map<String, Object> root = mapper.readValue(resp.body(), Map.class);
            Object offer = root.get("upgrade");
            if (offer instanceof Map<?, ?> o) {
                Object urls = o.get("urls");
                if (urls instanceof Map<?, ?> u && u.get("pricing") != null) {
                    upgradeUrl = String.valueOf(u.get("pricing"));
                }
                Object current = o.get("current_plan");
                if (current instanceof Map<?, ?> c && c.get("slug") != null) {
                    plan = String.valueOf(c.get("slug"));
                }
            }
        } catch (Exception ignored) {
            // non-JSON body — headers below are the only source
        }

        plan = resp.headers().firstValue("x-misar-plan").orElse(plan);
        upgradeUrl = resp.headers().firstValue("x-misar-upgrade-url").orElse(upgradeUrl);
        Integer retryAfter = resp.headers().firstValue("retry-after")
                .filter(v -> v.chars().allMatch(Character::isDigit))
                .map(Integer::valueOf)
                .orElse(null);

        return new PlanLimitException(status, message, plan, upgradeUrl, retryAfter);
    }

    @SuppressWarnings("unchecked")
    private String errorMessage(String body) {
        if (body == null || body.isBlank()) return "error";
        try {
            Object err = mapper.readValue(body, Map.class).get("error");
            if (err != null) return String.valueOf(err);
        } catch (Exception ignored) {
            // fall through
        }
        return body;
    }

    private <T> T model(Map<String, Object> map, Class<T> type) {
        return mapper.convertValue(map, type);
    }

    // ── Resources ─────────────────────────────────────────────────────────────

    /** Articles, drafts, search and recommendations. */
    public final class ArticlesResource {
        /** {@code GET /articles} — list your articles. */
        public Map<String, Object> list(Map<String, Object> params) throws BlogApiException {
            return request("GET", "/articles" + qs(params), null);
        }

        public Map<String, Object> list() throws BlogApiException {
            return list(null);
        }

        /** {@code GET /articles/{slug}} — get a single article by slug or UUID. */
        public Article get(String slug) throws BlogApiException {
            return model(request("GET", "/articles/" + enc(slug), null), Article.class);
        }

        /** {@code POST /articles} — publish or schedule an article. */
        public Article publish(Map<String, Object> body) throws BlogApiException {
            return model(request("POST", "/articles", body), Article.class);
        }

        /** {@code PATCH /articles/{slug}} — update a draft's title/body/tags, or publish it. */
        public Article update(String slug, Map<String, Object> body) throws BlogApiException {
            return model(request("PATCH", "/articles/" + enc(slug), body), Article.class);
        }

        /** {@code POST /drafts} — save an article as a draft. */
        public Article createDraft(Map<String, Object> body) throws BlogApiException {
            return model(request("POST", "/drafts", body), Article.class);
        }

        /** {@code GET /search} — search across articles, profiles, and tags. */
        public Map<String, Object> search(Map<String, Object> params) throws BlogApiException {
            return request("GET", "/search" + qs(params), null);
        }

        /** {@code GET /recommendations} — semantically similar public articles. */
        public Map<String, Object> recommendations(String articleId, Integer limit) throws BlogApiException {
            Map<String, Object> p = new LinkedHashMap<>();
            p.put("article_id", articleId);
            if (limit != null) p.put("limit", limit);
            return request("GET", "/recommendations" + qs(p), null);
        }
    }

    /** Series (collections of articles). */
    public final class SeriesResource {
        /** {@code GET /series} — list your series. */
        public Map<String, Object> list() throws BlogApiException {
            return request("GET", "/series", null);
        }

        /** {@code POST /series} — create a new series. */
        public Series create(Map<String, Object> body) throws BlogApiException {
            return model(request("POST", "/series", body), Series.class);
        }

        /** {@code POST /series/{slug}/articles} — add an article to a series. */
        public Map<String, Object> addArticle(String slug, Map<String, Object> body) throws BlogApiException {
            return request("POST", "/series/" + enc(slug) + "/articles", body);
        }
    }

    /** Article reactions (like/clap/bookmark). */
    public final class ReactionsResource {
        /** {@code GET /reactions} — reaction counts plus the caller's own reactions. */
        public Map<String, Object> get(String articleId) throws BlogApiException {
            return request("GET", "/reactions?article_id=" + enc(articleId), null);
        }

        /** {@code POST /reactions} — add or toggle a reaction on an article. */
        public Map<String, Object> add(Map<String, Object> body) throws BlogApiException {
            return request("POST", "/reactions", body);
        }

        /** {@code DELETE /reactions} — remove a reaction from an article. */
        public Map<String, Object> remove(String articleId, String type) throws BlogApiException {
            return request("DELETE", "/reactions?article_id=" + enc(articleId) + "&type=" + enc(type), null);
        }
    }

    /** Credit-spending AI helpers. */
    public final class AiResource {
        /** {@code POST /ai/complete} — generic system+user prompt completion. */
        public Map<String, Object> complete(Map<String, Object> body) throws BlogApiException {
            return request("POST", "/ai/complete", body);
        }

        /** {@code POST /ai/titles} — generate SEO/AEO/GEO title suggestions. */
        public Map<String, Object> titles(Map<String, Object> body) throws BlogApiException {
            return request("POST", "/ai/titles", body);
        }
    }

    /** CDN image upload and AI cover-image generation. */
    public final class ImagesResource {
        /** {@code POST /images/generate} — generate a cover image via AI and upload it. */
        public Map<String, Object> generate(Map<String, Object> body) throws BlogApiException {
            return request("POST", "/images/generate", body);
        }

        /** {@code POST /images/upload} — upload an image to the CDN. */
        public Map<String, Object> upload(Map<String, Object> body) throws BlogApiException {
            return request("POST", "/images/upload", body);
        }
    }

    /** Read access to an article's comment thread. */
    public final class CommentsResource {
        /**
         * {@code GET /comments} — an article's comment thread, newest first,
         * replies nested one level deep.
         *
         * @param articleId the article to read comments for
         * @param limit     1..100; {@code null} leaves the server default of 20
         * @param offset    {@code null} leaves the server default of 0
         */
        public Map<String, Object> list(String articleId, Integer limit, Integer offset)
                throws BlogApiException {
            Map<String, Object> p = new LinkedHashMap<>();
            p.put("article_id", articleId);
            if (limit != null) p.put("limit", limit);
            if (offset != null) p.put("offset", offset);
            return request("GET", "/comments" + qs(p), null);
        }

        /** {@code GET /comments} with the server's default paging. */
        public Map<String, Object> list(String articleId) throws BlogApiException {
            return list(articleId, null, null);
        }
    }

    /** Follower counts and the caller's follow state for a profile. */
    public final class FollowsResource {
        /**
         * {@code GET /follows} — a profile's follower/following counts plus
         * whether the key's owner follows it.
         */
        public Map<String, Object> status(String userId) throws BlogApiException {
            Map<String, Object> p = new LinkedHashMap<>();
            p.put("user_id", userId);
            return request("GET", "/follows" + qs(p), null);
        }
    }

    /** The authenticated creator's profile. */
    public final class AccountResource {
        /** {@code GET /me} — get the authenticated creator's profile. */
        public Map<String, Object> me() throws BlogApiException {
            return request("GET", "/me", null);
        }
    }

    /** Analytics summaries and the per-feature upsell funnel. */
    public final class AnalyticsResource {
        /** {@code GET /analytics} — analytics summary for the caller. */
        public Map<String, Object> summary(Integer days) throws BlogApiException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (days != null) p.put("days", days);
            return request("GET", "/analytics" + qs(p), null);
        }

        /** {@code GET /upsell-funnel} — per-feature upsell conversion funnel (admin-only). */
        public Map<String, Object> upsellFunnel(Integer days, String feature) throws BlogApiException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (days != null) p.put("days", days);
            if (feature != null) p.put("feature", feature);
            return request("GET", "/upsell-funnel" + qs(p), null);
        }
    }

    /** Live plan/quota information and the self-serve trial. */
    public final class PlanResource {
        /** {@code GET /plan} — live plan, quota and upgrade information. */
        public Map<String, Object> get() throws BlogApiException {
            return request("GET", "/plan", null);
        }

        /** {@code GET /trial} — self-serve, no-card trial eligibility and status. */
        public Map<String, Object> trialStatus() throws BlogApiException {
            return request("GET", "/trial", null);
        }

        /** {@code POST /trial} — start the self-serve, no-card trial (tightly rate-limited). */
        public Map<String, Object> startTrial(Map<String, Object> body) throws BlogApiException {
            return request("POST", "/trial", body);
        }
    }

    // ── Async convenience ─────────────────────────────────────────────────────

    /** Run any blocking call off the common pool, wrapping checked exceptions. */
    public <T> CompletableFuture<T> async(BlogSupplier<T> call) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return call.get();
            } catch (BlogApiException e) {
                throw new CompletionException(e);
            }
        });
    }

    /** A supplier that may throw {@link BlogApiException}. */
    @FunctionalInterface
    public interface BlogSupplier<T> {
        T get() throws BlogApiException;
    }

    // ── Embed helpers (public, unauthenticated) ───────────────────────────────

    /** Build a public embed URL for a creator profile or a specific article. */
    public static String embedUrl(String username, String slug, String theme) {
        StringBuilder url = new StringBuilder(EMBED_BASE + "/" + username);
        if (slug != null && !slug.isEmpty()) {
            url.append("/").append(slug);
        }
        url.append("/embed");
        if (theme != null && !theme.equals("auto")) {
            url.append("?theme=").append(theme);
        }
        return url.toString();
    }
}
