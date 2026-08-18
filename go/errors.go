package misarblog

import "fmt"

// APIError is returned when the Misar.Blog API responds with a non-2xx status.
type APIError struct {
	Status        int      `json:"-"`
	Message       string   `json:"error"`
	RequiredScope string   `json:"required_scope,omitempty"` // present on 403 scope failures
	GrantedScopes []string `json:"granted_scopes,omitempty"` // present on 403 scope failures
}

func (e *APIError) Error() string {
	return fmt.Sprintf("misarblog: API error %d: %s", e.Status, e.Message)
}

// PlanLimitError is returned when the subscription attached to the API key
// blocks the call. The API signals this with code "plan_limit_exceeded" and
// answers 429 when a metered allowance is exhausted (retryable once the period
// rolls over) or 402 when the feature is locked outright.
//
// It is surfaced as a distinct type rather than a generic 429 because retrying
// cannot help until the allowance resets or the plan changes — the SDK stops
// retrying as soon as it sees this code.
type PlanLimitError struct {
	Status int
	// Message is the human-readable headline plus call-to-action.
	Message string
	// Plan is the account's current plan slug.
	Plan string
	// UpgradeURL points at the pricing page for this account.
	UpgradeURL string
	// RetryAfter is seconds until the allowance resets, 0 when not supplied.
	RetryAfter int
	// Upgrade is the full upgrade offer from the response body.
	Upgrade map[string]any
}

func (e *PlanLimitError) Error() string {
	return fmt.Sprintf("misarblog: plan limit %d: %s (upgrade: %s)", e.Status, e.Message, e.UpgradeURL)
}

// NetworkError wraps a transport-level failure (the request never reached the API).
type NetworkError struct {
	Message string
	Cause   error
}

func (e *NetworkError) Error() string {
	return fmt.Sprintf("misarblog: network error: %s", e.Message)
}

func (e *NetworkError) Unwrap() error { return e.Cause }
