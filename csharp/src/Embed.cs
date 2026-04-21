namespace MisarBlog;

public static class Embed
{
    private const string EmbedBase = "https://misar.blog";

    public static string Url(string username, string? slug = null, string theme = "auto")
    {
        var url = string.IsNullOrEmpty(slug)
            ? $"{EmbedBase}/{username}/embed"
            : $"{EmbedBase}/{username}/{slug}/embed";

        if (!string.Equals(theme, "auto", StringComparison.OrdinalIgnoreCase))
            url += $"?theme={Uri.EscapeDataString(theme)}";

        return url;
    }
}
