<?php

declare(strict_types=1);

namespace MisarBlog;

class TrialResource
{
    public function __construct(private readonly Client $client) {}

    /** GET /trial */
    public function status(): array
    {
        return $this->client->request('GET', '/trial');
    }

    /** POST /trial */
    public function start(?string $feature = null, ?string $ref = null): array
    {
        $body = [];
        if ($feature !== null) {
            $body['feature'] = $feature;
        }
        if ($ref !== null) {
            $body['ref'] = $ref;
        }
        return $this->client->request('POST', '/trial', $body);
    }
}

// ── Resource: Analytics ─────────────────────────────────────────────────────────
