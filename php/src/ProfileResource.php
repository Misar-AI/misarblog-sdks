<?php

declare(strict_types=1);

namespace MisarBlog;

class ProfileResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /me */
    public function get(): array
    {
        return $this->client->request('GET', '/me');
    }
}

// ── Resource: Plan ──────────────────────────────────────────────────────────────
