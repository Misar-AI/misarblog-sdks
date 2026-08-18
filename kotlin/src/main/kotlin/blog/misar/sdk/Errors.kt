package blog.misar.sdk

/**
 * Thrown when the Misar.Blog API returns a non-2xx HTTP response.
 *
 * @property status HTTP status code returned by the server. The [message] is
 *   extracted from the standard `{"error": ...}` envelope when present.
 */
open class BlogApiException(
    val status: Int,
    message: String,
) : Exception("BlogApiException($status): $message")

/**
 * Thrown when a network-level error prevents the request from completing
 * (DNS/TLS/connection/timeout) or when the retry budget is exhausted.
 */
class BlogNetworkException(message: String) : BlogApiException(0, message)

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * The API signals this with `code: "plan_limit_exceeded"` and answers 429 when
 * a metered allowance is exhausted (retryable once the period rolls over) or
 * 402 when the feature is locked outright. It is a distinct type rather than a
 * generic 429 because retrying cannot help until the allowance resets or the
 * plan changes — the client stops retrying as soon as it sees this code.
 *
 * Surface [upgradeUrl] to the user rather than reporting a bare failure.
 *
 * @property plan       The account's current plan slug, when the API reports it.
 * @property upgradeUrl Pricing page to send the user to.
 * @property retryAfter Seconds until the allowance resets, when supplied.
 */
class PlanLimitException(
    status: Int,
    message: String,
    val plan: String? = null,
    val upgradeUrl: String? = null,
    val retryAfter: Int? = null,
) : BlogApiException(status, message)
