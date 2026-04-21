package blog.misar.sdk;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class MisarBlog {
    private static final String EMBED_BASE = "https://misar.blog";

    public record TokenResult(String token, long expiresAt) {}

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

    public static TokenResult refreshToken(String token, String baseUrl) throws Exception {
        String body = "{\"token\":\"" + token.replace("\"", "\\\"") + "\"}";
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/api/auth/refresh"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new RuntimeException("Refresh failed: " + response.statusCode());
        }

        String json = response.body();
        String tokenVal = extractJsonString(json, "token");
        long expiresAt = extractJsonLong(json, "expiresAt");
        return new TokenResult(tokenVal, expiresAt);
    }

    private static String extractJsonString(String json, String key) {
        String search = "\"" + key + "\":\"";
        int start = json.indexOf(search) + search.length();
        int end = json.indexOf("\"", start);
        return json.substring(start, end);
    }

    private static long extractJsonLong(String json, String key) {
        String search = "\"" + key + "\":";
        int start = json.indexOf(search) + search.length();
        int end = start;
        while (end < json.length() && (Character.isDigit(json.charAt(end)) || json.charAt(end) == '-')) {
            end++;
        }
        return Long.parseLong(json.substring(start, end));
    }
}
