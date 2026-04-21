package blog.misar.sdk

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.Serializable

private const val EMBED_BASE = "https://misar.blog"

@Serializable
data class TokenResult(val token: String, val expiresAt: Long)

@Serializable
private data class RefreshRequest(val token: String)

object MisarBlog {
    fun embedUrl(username: String, slug: String? = null, theme: String = "auto"): String {
        val path = if (slug != null) "$username/$slug/embed" else "$username/embed"
        return if (theme != "auto") "$EMBED_BASE/$path?theme=$theme" else "$EMBED_BASE/$path"
    }

    suspend fun refreshToken(token: String, baseUrl: String = EMBED_BASE): TokenResult {
        val client = HttpClient(CIO) {
            install(ContentNegotiation) { json() }
        }
        return client.use {
            it.post("$baseUrl/api/auth/refresh") {
                contentType(ContentType.Application.Json)
                setBody(RefreshRequest(token))
            }.body()
        }
    }
}
