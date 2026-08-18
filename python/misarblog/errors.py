"""Error types for the Misar.Blog developer API SDK."""

from __future__ import annotations

from typing import Any, Optional


class MisarBlogError(Exception):
    """Raised when the API returns a non-2xx response.

    Attributes:
        status: HTTP status code (0 for network/transport errors).
        error_type: Coarse category — ``api_error`` or ``network_error``.
        payload: The decoded JSON error body, when available.
        required_scope: Present on 403 scope failures (``required_scope`` field).
        granted_scopes: Present on 403 scope failures (``granted_scopes`` field).
    """

    def __init__(
        self,
        status: int,
        message: str,
        error_type: str = "api_error",
        payload: Optional[dict[str, Any]] = None,
    ) -> None:
        self.status = status
        self.error_type = error_type
        self.payload = payload or {}
        self.required_scope: Optional[str] = self.payload.get("required_scope")
        self.granted_scopes: Optional[list[str]] = self.payload.get("granted_scopes")
        super().__init__(f"misar-blog: API error {status} ({error_type}): {message}")


class MisarBlogNetworkError(MisarBlogError):
    """Raised when the request could not reach the API (transport failure)."""

    def __init__(self, message: str, cause: Optional[Exception] = None) -> None:
        self.cause = cause
        super().__init__(0, message, "network_error")


class MisarBlogPlanLimitError(MisarBlogError):
    """Raised when the account's subscription plan blocks the call.

    The API signals this with ``code: "plan_limit_exceeded"`` and answers 429
    when a metered allowance is exhausted (retryable once the period rolls
    over) or 402 when the feature is locked outright. Both carry an upgrade
    offer, so this is surfaced as its own type rather than as a generic 429 —
    retrying will not help until the plan changes or the period resets.

    Attributes:
        plan: The account's current plan slug.
        upgrade_url: Pricing page to send the user to.
        retry_after: Seconds until the allowance resets, when the API says so.
        upgrade: The full upgrade offer object from the response body.
    """

    def __init__(
        self,
        status: int,
        message: str,
        payload: Optional[dict[str, Any]] = None,
        headers: Optional[dict[str, str]] = None,
    ) -> None:
        h = {k.lower(): v for k, v in (headers or {}).items()}
        data = payload or {}
        upgrade = data.get("upgrade") if isinstance(data.get("upgrade"), dict) else {}
        self.plan: Optional[str] = h.get("x-misar-plan") or (
            (upgrade.get("current_plan") or {}).get("slug") if upgrade else None
        )
        self.upgrade_url: Optional[str] = h.get("x-misar-upgrade-url") or (
            (upgrade.get("urls") or {}).get("pricing") if upgrade else None
        )
        retry = h.get("retry-after")
        self.retry_after: Optional[int] = int(retry) if retry and retry.isdigit() else None
        self.upgrade: dict[str, Any] = upgrade or {}
        super().__init__(status, message, "plan_limit_exceeded", data)
