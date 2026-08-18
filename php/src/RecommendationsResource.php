<?php

declare(strict_types=1);

namespace MisarBlog;

class RecommendationsResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /recommendations */
    public function get(string $articleId, ?int $limit = null): array
    {
        $params = ['article_id' => $articleId];
        if ($limit !== null) {
            $params['limit'] = $limit;
        }
        return $this->client->request('GET', '/recommendations?' . http_build_query($params));
    }
}

// ── Resource: Search ────────────────────────────────────────────────────────────
