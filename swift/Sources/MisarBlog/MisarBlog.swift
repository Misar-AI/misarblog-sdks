import Foundation

public class MisarBlog {
    private let embedBase = "https://misar.blog"

    public struct TokenResult: Codable {
        public let token: String
        public let expiresAt: Int64
    }

    private struct RefreshRequest: Codable {
        let token: String
    }

    public func embedURL(username: String, slug: String? = nil, theme: String = "auto") -> URL {
        var components = URLComponents(string: embedBase)!
        components.path = slug.map { "/\(username)/\($0)/embed" } ?? "/\(username)/embed"
        if theme != "auto" {
            components.queryItems = [URLQueryItem(name: "theme", value: theme)]
        }
        return components.url!
    }

    public func refreshToken(token: String, baseURL: String = "https://misar.blog") async throws -> TokenResult {
        guard let url = URL(string: "\(baseURL)/api/auth/refresh") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(token: token))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TokenResult.self, from: data)
    }
}
