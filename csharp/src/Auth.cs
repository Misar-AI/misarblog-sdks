using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace MisarBlog;

public record TokenResult(
    [property: JsonPropertyName("token")] string Token,
    [property: JsonPropertyName("expiresAt")] long ExpiresAt
);

public static class Auth
{
    public static async Task<TokenResult> RefreshToken(
        string token,
        string baseUrl = "https://misar.blog",
        HttpClient? client = null)
    {
        var owned = client is null;
        client ??= new HttpClient();
        try
        {
            var response = await client.PostAsJsonAsync(
                $"{baseUrl}/api/auth/refresh",
                new { token });
            response.EnsureSuccessStatusCode();
            return (await response.Content.ReadFromJsonAsync<TokenResult>())!;
        }
        finally
        {
            if (owned) client.Dispose();
        }
    }
}
