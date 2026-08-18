namespace MisarBlog;

/// <summary>
/// Thrown when the Misar.Blog developer API returns a non-2xx HTTP response.
/// </summary>
public class MisarBlogException : Exception
{
    /// <summary>HTTP status code returned by the server.</summary>
    public int Status { get; }

    /// <summary>Scope the key would need, when the API reports one (403).</summary>
    public string? RequiredScope { get; }

    /// <summary>Scopes the presented key carries, when the API reports them (403).</summary>
    public IReadOnlyList<string> GrantedScopes { get; }

    public MisarBlogException(
        int status,
        string message,
        string? requiredScope = null,
        IReadOnlyList<string>? grantedScopes = null)
        : base($"MisarBlogException({status}): {message}")
    {
        Status = status;
        RequiredScope = requiredScope;
        GrantedScopes = grantedScopes ?? Array.Empty<string>();
    }

    public MisarBlogException(int status, string message, Exception inner)
        : base($"MisarBlogException({status}): {message}", inner)
    {
        Status = status;
        GrantedScopes = Array.Empty<string>();
    }
}

/// <summary>
/// Thrown when the subscription attached to the API key blocks the call.
/// </summary>
/// <remarks>
/// The API signals this with <c>code: "plan_limit_exceeded"</c> and answers 429
/// when a metered allowance is exhausted (retryable once the period rolls over)
/// or 402 when the feature is locked outright. It is a distinct type rather
/// than a generic 429 because retrying cannot help until the allowance resets
/// or the plan changes — the client stops retrying as soon as it sees this code.
/// </remarks>
public sealed class MisarBlogPlanLimitException : MisarBlogException
{
    /// <summary>The account's current plan slug, when the API reports it.</summary>
    public string? Plan { get; }

    /// <summary>Pricing page to send the user to.</summary>
    public string? UpgradeUrl { get; }

    /// <summary>Seconds until the allowance resets, when the API supplies it.</summary>
    public int? RetryAfter { get; }

    public MisarBlogPlanLimitException(
        int status,
        string message,
        string? plan = null,
        string? upgradeUrl = null,
        int? retryAfter = null)
        : base(status, message)
    {
        Plan = plan;
        UpgradeUrl = upgradeUrl;
        RetryAfter = retryAfter;
    }
}

/// <summary>
/// Thrown when a network-level error prevents the request from completing,
/// or when the maximum number of retries is exhausted.
/// </summary>
public sealed class MisarBlogNetworkException : MisarBlogException
{
    public MisarBlogNetworkException(string message)
        : base(0, message) { }

    public MisarBlogNetworkException(string message, Exception inner)
        : base(0, message, inner) { }
}
