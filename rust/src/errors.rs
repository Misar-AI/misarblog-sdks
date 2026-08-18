use thiserror::Error;

/// Errors returned by the Misar.Blog SDK.
#[derive(Debug, Error)]
pub enum BlogApiError {
    /// The API responded with a non-2xx status. For network-level failures the
    /// `status` is `0`.
    #[error("Blog API error {status}: {message}")]
    Api {
        /// HTTP status code (`0` for a network-level failure or exhausted retries).
        status: u16,
        /// Human-readable message, extracted from the standard `{ "error": ... }` envelope.
        message: String,
    },

    /// The subscription attached to the API key blocks this call.
    ///
    /// The API signals this with `code: "plan_limit_exceeded"` and answers 429
    /// when a metered allowance is exhausted (retryable once the period rolls
    /// over) or 402 when the feature is locked outright. It is a distinct
    /// variant rather than a generic 429 because retrying cannot help until the
    /// allowance resets or the plan changes — the SDK stops retrying on sight.
    #[error("Plan limit ({status}): {message}")]
    PlanLimit {
        /// HTTP status — 429 (allowance exhausted) or 402 (feature locked).
        status: u16,
        /// Headline plus call-to-action from the upgrade offer.
        message: String,
        /// The account's current plan slug, when the API reports it.
        plan: Option<String>,
        /// Pricing page to send the user to.
        upgrade_url: Option<String>,
        /// Seconds until the allowance resets, when the API supplies it.
        retry_after: Option<u64>,
    },

    /// A transport/network error occurred (DNS, TLS, connection, timeout).
    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    /// Request serialization or response deserialization failed.
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

impl BlogApiError {
    /// The HTTP status associated with the error, or `0` for network/JSON errors.
    pub fn status(&self) -> u16 {
        match self {
            BlogApiError::Api { status, .. } | BlogApiError::PlanLimit { status, .. } => *status,
            _ => 0,
        }
    }

    /// The pricing URL to send the user to, when this error is a plan refusal.
    pub fn upgrade_url(&self) -> Option<&str> {
        match self {
            BlogApiError::PlanLimit { upgrade_url, .. } => upgrade_url.as_deref(),
            _ => None,
        }
    }
}
