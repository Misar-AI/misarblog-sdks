<?php

declare(strict_types=1);

namespace MisarBlog;

class UpsellResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /upsell-funnel */
    public function funnel(?int $days = null, ?string $feature = null): array
    {
        $params = [];
        if ($days !== null) {
            $params['days'] = $days;
        }
        if ($feature !== null) {
            $params['feature'] = $feature;
        }
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/upsell-funnel{$qs}");
    }
}

// ── Main Client ─────────────────────────────────────────────────────────────────
