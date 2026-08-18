<?php

declare(strict_types=1);

namespace MisarBlog;

class SeriesResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /series */
    public function list(): array
    {
        return $this->client->request('GET', '/series');
    }

    /** POST /series */
    public function create(string $title, ?string $description = null): array
    {
        $body = ['title' => $title];
        if ($description !== null) {
            $body['description'] = $description;
        }
        return $this->client->request('POST', '/series', $body);
    }

    /** POST /series/{slug}/articles */
    public function addArticle(string $slug, string $articleSlug, ?int $position = null): array
    {
        $body = ['article_slug' => $articleSlug];
        if ($position !== null) {
            $body['position'] = $position;
        }
        return $this->client->request('POST', '/series/' . rawurlencode($slug) . '/articles', $body);
    }
}

// ── Resource: Trial ─────────────────────────────────────────────────────────────
