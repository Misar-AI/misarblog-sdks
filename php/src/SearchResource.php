<?php

declare(strict_types=1);

namespace MisarBlog;

class SearchResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /search
     * @param array<string,scalar> $params q, type, tag, author, sort, from, to, limit
     */
    public function query(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/search{$qs}");
    }
}

// ── Resource: Series ────────────────────────────────────────────────────────────
