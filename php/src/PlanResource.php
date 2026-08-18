<?php

declare(strict_types=1);

namespace MisarBlog;

class PlanResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /plan */
    public function get(): array
    {
        return $this->client->request('GET', '/plan');
    }
}

// ── Resource: Reactions ─────────────────────────────────────────────────────────
