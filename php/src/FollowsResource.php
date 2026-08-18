<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * GET /follows — follower counts and the caller's follow state.
 */
class FollowsResource
{
    public function __construct(private readonly Client $client) {}

    /** @return array<string,mixed> */
    public function status(string $userId): array
    {
        return $this->client->request('GET', '/follows?' . http_build_query(['user_id' => $userId]));
    }
}
