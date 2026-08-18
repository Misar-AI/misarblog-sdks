<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * Thrown when the Misar.Blog developer API returns a non-2xx HTTP response.
 */
class ApiError extends \RuntimeException
{
    /**
     * @param list<string> $grantedScopes
     */
    public function __construct(
        string $message,
        public readonly int $status = 0,
        public readonly ?string $requiredScope = null,
        public readonly array $grantedScopes = [],
        ?\Throwable $previous = null,
    ) {
        parent::__construct($message, $status, $previous);
    }
}
