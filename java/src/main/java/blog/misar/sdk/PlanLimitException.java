package blog.misar.sdk;

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * <p>The API signals this with {@code code: "plan_limit_exceeded"} and answers
 * 429 when a metered allowance is exhausted (retryable once the period rolls
 * over) or 402 when the feature is locked outright.
 *
 * <p>It is a distinct type rather than a generic 429 because retrying cannot
 * help until the allowance resets or the plan changes — the client stops
 * retrying as soon as it sees this code. Surface {@link #getUpgradeUrl()} to
 * the user rather than reporting a bare failure.
 */
public class PlanLimitException extends BlogApiException {

    private final String plan;
    private final String upgradeUrl;
    private final Integer retryAfter;

    /**
     * @param status     429 (allowance exhausted) or 402 (feature locked).
     * @param message    Headline plus call-to-action from the upgrade offer.
     * @param plan       The account's current plan slug, or {@code null}.
     * @param upgradeUrl Pricing page to send the user to, or {@code null}.
     * @param retryAfter Seconds until the allowance resets, or {@code null}.
     */
    public PlanLimitException(int status, String message, String plan, String upgradeUrl, Integer retryAfter) {
        super(status, message);
        this.plan = plan;
        this.upgradeUrl = upgradeUrl;
        this.retryAfter = retryAfter;
    }

    /** The account's current plan slug, or {@code null} when not reported. */
    public String getPlan() {
        return plan;
    }

    /** Pricing page to send the user to, or {@code null} when not reported. */
    public String getUpgradeUrl() {
        return upgradeUrl;
    }

    /** Seconds until the allowance resets, or {@code null} when not supplied. */
    public Integer getRetryAfter() {
        return retryAfter;
    }
}
