<?php

declare(strict_types=1);

namespace MisarBlog;

class ArticlesResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /articles
     * @param array<string,scalar> $params status, visibility, webhook_only, sort, limit
     */
    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/articles{$qs}");
    }

    /** GET /articles/{slug} */
    public function get(string $slug): array
    {
        return $this->client->request('GET', '/articles/' . rawurlencode($slug));
    }

    /** PATCH /articles/{slug} — title, body_markdown, tags, publish */
    public function update(string $slug, array $data): array
    {
        return $this->client->request('PATCH', '/articles/' . rawurlencode($slug), $data);
    }

    /** POST /articles — requires title + body_markdown */
    public function publish(array $data): array
    {
        return $this->client->request('POST', '/articles', $data);
    }

    /** POST /drafts — requires title + body_markdown */
    public function createDraft(array $data): array
    {
        return $this->client->request('POST', '/drafts', $data);
    }
}

// ── Resource: Images ────────────────────────────────────────────────────────────
