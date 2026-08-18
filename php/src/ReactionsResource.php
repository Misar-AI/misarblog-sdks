<?php

declare(strict_types=1);

namespace MisarBlog;

class ReactionsResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /reactions */
    public function get(string $articleId): array
    {
        return $this->client->request('GET', '/reactions?' . http_build_query(['article_id' => $articleId]));
    }

    /** POST /reactions */
    public function add(string $articleId, string $type): array
    {
        return $this->client->request('POST', '/reactions', ['article_id' => $articleId, 'type' => $type]);
    }

    /** DELETE /reactions */
    public function remove(string $articleId, string $type): array
    {
        return $this->client->request('DELETE', '/reactions?' . http_build_query(['article_id' => $articleId, 'type' => $type]));
    }
}

// ── Resource: Recommendations ───────────────────────────────────────────────────
