<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * The API signals this with `code: "plan_limit_exceeded"` and answers 429 when
 * a metered allowance is exhausted (retryable once the period rolls over) or
 * 402 when the feature is locked outright. It is a distinct class rather than a
 * generic 429 because retrying cannot help until the allowance resets or the
 * plan changes — the client stops retrying as soon as it sees this code.
 */
class PlanLimitError extends ApiError
{
    /**
     * @param array<string,mixed> $upgrade the full upgrade offer from the body
     */
    public function __construct(
        string $message,
        int $status,
        public readonly ?string $plan = null,
        public readonly ?string $upgradeUrl = null,
        public readonly ?int $retryAfter = null,
        public readonly array $upgrade = [],
    ) {
        parent::__construct($message, $status);
    }
}
