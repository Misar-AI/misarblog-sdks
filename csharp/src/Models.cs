using System.Text.Json;
using System.Text.Json.Serialization;

namespace MisarBlog;

/// <summary>
/// A blog article, per the OpenAPI <c>Article</c> schema. The dev API returns
/// plain JSON; resource methods hand back a <see cref="JsonElement"/>. Use
/// <see cref="From"/> to project one into this typed view.
/// </summary>
public sealed record Article(
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("slug")] string? Slug,
    [property: JsonPropertyName("title")] string? Title,
    [property: JsonPropertyName("status")] string? Status,
    [property: JsonPropertyName("url")] string? Url,
    [property: JsonPropertyName("editor_url")] string? EditorUrl,
    [property: JsonPropertyName("excerpt")] string? Excerpt,
    [property: JsonPropertyName("tags")] IReadOnlyList<string>? Tags,
    [property: JsonPropertyName("visibility")] string? Visibility,
    [property: JsonPropertyName("published_at")] string? PublishedAt,
    [property: JsonPropertyName("created_at")] string? CreatedAt)
{
    /// <summary>Project a raw JSON payload into an <see cref="Article"/>.</summary>
    public static Article? From(JsonElement json) =>
        json.Deserialize<Article>();
}

/// <summary>A series/collection of articles, per the <c>Series</c> schema.</summary>
public sealed record Series(
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("slug")] string? Slug,
    [property: JsonPropertyName("title")] string? Title,
    [property: JsonPropertyName("description")] string? Description,
    [property: JsonPropertyName("article_count")] int? ArticleCount,
    [property: JsonPropertyName("created_at")] string? CreatedAt)
{
    /// <summary>Project a raw JSON payload into a <see cref="Series"/>.</summary>
    public static Series? From(JsonElement json) =>
        json.Deserialize<Series>();
}
