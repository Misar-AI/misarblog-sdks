<?php

declare(strict_types=1);

namespace MisarBlog;

class AnalyticsResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /analytics */
    public function get(?int $days = null): array
    {
        $qs = $days !== null ? '?' . http_build_query(['days' => $days]) : '';
        return $this->client->request('GET', "/analytics{$qs}");
    }
}

// ── Resource: Upsell ────────────────────────────────────────────────────────────
