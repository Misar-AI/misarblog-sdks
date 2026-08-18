package blog.misar.sdk

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.time.Duration

/**
 * Client for the **Misar.Blog developer API** — full coverage of the 25
 * key-authenticated operations.
 *
 * Authentication uses a developer key sent as `Authorization: Bearer mbk_...`
 * (OAuth 2.1 access tokens are accepted on the same header). The default base URL
 * is `https://api.misar.io/blog/v1` — the gateway strips `/api`.
 *
 * All suspend methods perform up to [maxRetries] attempts with exponential
 * back-off (starting at 500 ms) on retryable HTTP statuses (429, 500, 502, 503,
 * 504) and network errors. The request is sent on every attempt including the
 * last one.
 *
 * ```kotlin
 * val blog = MisarBlog("mbk_...")
 * val article = blog.articles.publish(mapOf("title" to "Hello", "body_markdown" to "# Hi"))
 * ```
 */
class MisarBlog(
    private val apiKey: String,
    baseUrl: String = "https://api.misar.io/blog/v1",
    private val maxRetries: Int = 3,
) {
    private val base = baseUrl.trimEnd('/')
    private val retries = maxRetries.coerceAtLeast(1)

    private val http: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10))
        .build()

    private val mapper = jacksonObjectMapper()

    // ── resource accessors ────────────────────────────────────────────────────
    val articles = ArticlesResource()
    val series = SeriesResource()
    val reactions = ReactionsResource()
    val ai = AiResource()
    val images = ImagesResource()
    val account = AccountResource()
    val analytics = AnalyticsResource()
    val plan = PlanResource()
    val comments = CommentsResource()
    val follows = FollowsResource()

    // ── Core HTTP ─────────────────────────────────────────────────────────────

    private fun Map<String, Any?>.toQueryString(): String {
        val pairs = entries.filter { it.value != null }
        if (pairs.isEmpty()) return ""
        return "?" + pairs.joinToString("&") { (k, v) ->
            "${URLEncoder.encode(k, StandardCharsets.UTF_8)}=${URLEncoder.encode(v.toString(), StandardCharsets.UTF_8)}"
        }
    }

    private fun enc(s: String) = URLEncoder.encode(s, StandardCharsets.UTF_8)

    private suspend fun request(method: String, path: String, body: Any? = null): Map<String, Any> =
        withContext(Dispatchers.IO) {
            val url = "$base$path"
            val bodyStr = if (body != null) mapper.writeValueAsString(body) else null
            var lastException: Exception? = null
            var delayMs = 500L

            repeat(retries) { attempt ->
                if (attempt > 0) {
                    delay(delayMs)
                    delayMs *= 2
                }

                val publisher = if (bodyStr != null) {
                    HttpRequest.BodyPublishers.ofString(bodyStr)
                } else {
                    HttpRequest.BodyPublishers.noBody()
                }

                val request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(30))
                    .header("Authorization", "Bearer $apiKey")
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .method(method, publisher)
                    .build()

                val response: HttpResponse<String>
                try {
                    response = http.send(request, HttpResponse.BodyHandlers.ofString())
                } catch (e: Exception) {
                    lastException = BlogNetworkException(e.message ?: "network error")
                    return@repeat
                }

                val status = response.statusCode()

                // A plan-limit 429 is not "slow down": retrying cannot help
                // until the allowance resets or the plan changes, so surface it
                // immediately instead of burning the retry budget.
                if (isPlanLimit(response.body())) {
                    throw planLimitException(status, response)
                }

                // Retry only when attempts remain; the final attempt returns the real result.
                if (status in RETRYABLE && attempt < retries - 1) {
                    lastException = BlogApiException(status, errorMessage(response.body()))
                    return@repeat
                }

                if (status in 200..299) {
                    val rb = response.body()
                    return@withContext if (rb.isNullOrBlank()) emptyMap() else mapper.readValue(rb)
                }

                throw BlogApiException(status, errorMessage(response.body()))
            }

            throw lastException ?: BlogNetworkException("max retries exceeded")
        }

    /** True when an error body carries the API's plan-limit code. */
    private fun isPlanLimit(body: String?): Boolean {
        if (body.isNullOrBlank()) return false
        return runCatching {
            mapper.readValue<Map<String, Any>>(body)["code"] == "plan_limit_exceeded"
        }.getOrDefault(false)
    }

    private fun planLimitException(status: Int, response: HttpResponse<String>): PlanLimitException {
        val offer = runCatching {
            @Suppress("UNCHECKED_CAST")
            mapper.readValue<Map<String, Any>>(response.body())["upgrade"] as? Map<String, Any>
        }.getOrNull().orEmpty()

        @Suppress("UNCHECKED_CAST")
        val bodyUrl = (offer["urls"] as? Map<String, Any>)?.get("pricing")?.toString()
        @Suppress("UNCHECKED_CAST")
        val bodyPlan = (offer["current_plan"] as? Map<String, Any>)?.get("slug")?.toString()

        // Headers are authoritative; fall back to the offer body when a proxy
        // has stripped them.
        val header = { name: String -> response.headers().firstValue(name).orElse(null) }

        return PlanLimitException(
            status = status,
            message = errorMessage(response.body()),
            plan = header("x-misar-plan") ?: bodyPlan,
            upgradeUrl = header("x-misar-upgrade-url") ?: bodyUrl,
            retryAfter = header("retry-after")?.toIntOrNull(),
        )
    }

    private fun errorMessage(body: String?): String {
        if (body.isNullOrBlank()) return "error"
        return runCatching {
            (mapper.readValue<Map<String, Any>>(body)["error"])?.toString()
        }.getOrNull() ?: body
    }

    private inline fun <reified T> model(map: Map<String, Any>): T =
        mapper.convertValue(map, T::class.java)

    // ── Resources ─────────────────────────────────────────────────────────────

    /** Articles, drafts, search and recommendations. */
    inner class ArticlesResource {
        /** GET /articles — list your articles. */
        suspend fun list(params: Map<String, Any?> = emptyMap()): Map<String, Any> =
            request("GET", "/articles${params.toQueryString()}")

        /** GET /articles/{slug} — get a single article by slug or UUID. */
        suspend fun get(slug: String): Article =
            model(request("GET", "/articles/${enc(slug)}"))

        /** POST /articles — publish or schedule an article. */
        suspend fun publish(body: Map<String, Any?>): Article =
            model(request("POST", "/articles", body))

        /** PATCH /articles/{slug} — update a draft's title/body/tags, or publish it. */
        suspend fun update(slug: String, body: Map<String, Any?>): Article =
            model(request("PATCH", "/articles/${enc(slug)}", body))

        /** POST /drafts — save an article as a draft. */
        suspend fun createDraft(body: Map<String, Any?>): Article =
            model(request("POST", "/drafts", body))

        /** GET /search — search across articles, profiles, and tags. */
        suspend fun search(params: Map<String, Any?> = emptyMap()): Map<String, Any> =
            request("GET", "/search${params.toQueryString()}")

        /** GET /recommendations — semantically similar public articles. */
        suspend fun recommendations(articleId: String, limit: Int? = null): Map<String, Any> =
            request("GET", "/recommendations${mapOf("article_id" to articleId, "limit" to limit).toQueryString()}")
    }

    /** Series (collections of articles). */
    inner class SeriesResource {
        /** GET /series — list your series. */
        suspend fun list(): Map<String, Any> =
            request("GET", "/series")

        /** POST /series — create a new series. */
        suspend fun create(body: Map<String, Any?>): Series =
            model(request("POST", "/series", body))

        /** POST /series/{slug}/articles — add an article to a series. */
        suspend fun addArticle(slug: String, body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/series/${enc(slug)}/articles", body)
    }

    /** Article reactions (like/clap/bookmark). */
    inner class ReactionsResource {
        /** GET /reactions — reaction counts plus the caller's own reactions. */
        suspend fun get(articleId: String): Map<String, Any> =
            request("GET", "/reactions?article_id=${enc(articleId)}")

        /** POST /reactions — add or toggle a reaction on an article. */
        suspend fun add(body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/reactions", body)

        /** DELETE /reactions — remove a reaction from an article. */
        suspend fun remove(articleId: String, type: String): Map<String, Any> =
            request("DELETE", "/reactions?article_id=${enc(articleId)}&type=${enc(type)}")
    }

    /** Credit-spending AI helpers. */
    inner class AiResource {
        /** POST /ai/complete — generic system+user prompt completion. */
        suspend fun complete(body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/ai/complete", body)

        /** POST /ai/titles — generate SEO/AEO/GEO title suggestions. */
        suspend fun titles(body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/ai/titles", body)
    }

    /** CDN image upload and AI cover-image generation. */
    inner class ImagesResource {
        /** POST /images/generate — generate a cover image via AI and upload it. */
        suspend fun generate(body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/images/generate", body)

        /** POST /images/upload — upload an image to the CDN. */
        suspend fun upload(body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/images/upload", body)
    }

    /** The authenticated creator's profile. */
    inner class AccountResource {
        /** GET /me — get the authenticated creator's profile. */
        suspend fun me(): Map<String, Any> =
            request("GET", "/me")
    }

    /** Analytics summaries and the per-feature upsell funnel. */
    inner class AnalyticsResource {
        /** GET /analytics — analytics summary for the caller. */
        suspend fun summary(days: Int? = null): Map<String, Any> =
            request("GET", "/analytics${mapOf("days" to days).toQueryString()}")

        /** GET /upsell-funnel — per-feature upsell conversion funnel (admin-only). */
        suspend fun upsellFunnel(days: Int? = null, feature: String? = null): Map<String, Any> =
            request("GET", "/upsell-funnel${mapOf("days" to days, "feature" to feature).toQueryString()}")
    }

    /** Read access to an article's comment thread. */
    inner class CommentsResource {
        /**
         * `GET /comments` — an article's comment thread, newest first, replies
         * nested one level deep. [limit] defaults to 20 (max 100) and [offset]
         * to 0 server-side.
         */
        suspend fun list(articleId: String, limit: Int? = null, offset: Int? = null): Map<String, Any> =
            request("GET", "/comments" + mapOf(
                "article_id" to articleId,
                "limit" to limit,
                "offset" to offset,
            ).toQueryString())
    }

    /** Follower counts and the caller's follow state for a profile. */
    inner class FollowsResource {
        /**
         * `GET /follows` — a profile's follower/following counts plus whether
         * the key's owner follows it.
         */
        suspend fun status(userId: String): Map<String, Any> =
            request("GET", "/follows" + mapOf("user_id" to userId).toQueryString())
    }

    /** Live plan/quota information and the self-serve trial. */
    inner class PlanResource {
        /** GET /plan — live plan, quota and upgrade information. */
        suspend fun get(): Map<String, Any> =
            request("GET", "/plan")

        /** GET /trial — self-serve, no-card trial eligibility and status. */
        suspend fun trialStatus(): Map<String, Any> =
            request("GET", "/trial")

        /** POST /trial — start the self-serve, no-card trial (tightly rate-limited). */
        suspend fun startTrial(body: Map<String, Any?>): Map<String, Any> =
            request("POST", "/trial", body)
    }

    companion object {
        private val RETRYABLE = setOf(429, 500, 502, 503, 504)
        private const val EMBED_BASE = "https://misar.blog"

        /** Build a public embed URL for a creator profile or a specific article. */
        fun embedUrl(username: String, slug: String? = null, theme: String = "auto"): String {
            val path = if (slug != null) "$username/$slug/embed" else "$username/embed"
            return if (theme != "auto") "$EMBED_BASE/$path?theme=$theme" else "$EMBED_BASE/$path"
        }
    }
}
