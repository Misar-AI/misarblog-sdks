import Foundation

// URLSession, URLRequest and HTTPURLResponse live in FoundationNetworking on
// Linux rather than Foundation.
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors thrown by ``MisarBlogClient``.
public enum MisarBlogError: Error, CustomStringConvertible {

    /// The API returned a non-2xx HTTP response.
    ///
    /// - Parameters:
    ///   - status:         HTTP status code.
    ///   - message:        Human-readable description from the API response body.
    ///   - requiredScope:  Scope the key would need for this call, when the API
    ///                     reports one (403 responses).
    ///   - grantedScopes:  Scopes the presented key actually carries, when the
    ///                     API reports them (403 responses).
    case apiError(status: Int, message: String, requiredScope: String? = nil, grantedScopes: [String] = [])

    /// The subscription attached to the API key blocks this call.
    ///
    /// The API signals this with `code: "plan_limit_exceeded"` and answers 429
    /// when a metered allowance is exhausted (retryable once the period rolls
    /// over) or 402 when the feature is locked outright. It is a distinct case
    /// rather than a generic 429 because retrying cannot help until the
    /// allowance resets or the plan changes — the client stops retrying on sight.
    ///
    /// - Parameters:
    ///   - status:      429 (allowance exhausted) or 402 (feature locked).
    ///   - message:     Headline plus call-to-action from the upgrade offer.
    ///   - plan:        The account's current plan slug, when reported.
    ///   - upgradeURL:  Pricing page to send the user to.
    ///   - retryAfter:  Seconds until the allowance resets, when supplied.
    case planLimitExceeded(
        status: Int,
        message: String,
        plan: String? = nil,
        upgradeURL: String? = nil,
        retryAfter: Int? = nil
    )

    /// A network-level error prevented the request from completing, or the
    /// maximum number of retries was exhausted.
    ///
    /// - Parameter message: Underlying error description.
    case networkError(message: String)

    public var description: String {
        switch self {
        case let .apiError(status, message, requiredScope, grantedScopes):
            var out = "MisarBlogError.apiError(\(status)): \(message)"
            if let requiredScope { out += " [required_scope=\(requiredScope)]" }
            if !grantedScopes.isEmpty { out += " [granted_scopes=\(grantedScopes.joined(separator: ","))]" }
            return out
        case let .planLimitExceeded(status, message, plan, upgradeURL, _):
            var out = "MisarBlogError.planLimitExceeded(\(status)): \(message)"
            if let plan { out += " [plan=\(plan)]" }
            if let upgradeURL { out += " [upgrade=\(upgradeURL)]" }
            return out
        case let .networkError(message):
            return "MisarBlogError.networkError: \(message)"
        }
    }
}

public extension MisarBlogError {
    /// The pricing URL to send the user to, when this error is a plan refusal.
    var upgradeURL: String? {
        if case let .planLimitExceeded(_, _, _, url, _) = self { return url }
        return nil
    }
}
