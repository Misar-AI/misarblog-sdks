package blog.misar.sdk

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import com.fasterxml.jackson.annotation.JsonProperty

/** A blog article as returned by the publish/draft/get/update endpoints. */
@JsonIgnoreProperties(ignoreUnknown = true)
data class Article(
    val id: String,
    val slug: String,
    val title: String,
    val status: String,
    val url: String,
    @JsonProperty("editor_url") val editorUrl: String,
    val excerpt: String? = null,
    val tags: List<String> = emptyList(),
    val visibility: String? = null,
    @JsonProperty("published_at") val publishedAt: String? = null,
    @JsonProperty("created_at") val createdAt: String? = null,
)

/** A series (collection) of articles. */
@JsonIgnoreProperties(ignoreUnknown = true)
data class Series(
    val id: String,
    val slug: String,
    val title: String,
    val description: String? = null,
    @JsonProperty("article_count") val articleCount: Int = 0,
    @JsonProperty("created_at") val createdAt: String? = null,
)

/** Result of an embed-token refresh. */
data class TokenResult(
    val token: String,
    @JsonProperty("expiresAt") val expiresAt: Long,
)
