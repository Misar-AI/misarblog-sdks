<?php

declare(strict_types=1);

namespace MisarBlog;

class ImagesResource
{
    public function __construct(private readonly Client $client) {}

    /** POST /images/generate */
    public function generate(string $prompt, ?string $size = null): array
    {
        $body = ['prompt' => $prompt];
        if ($size !== null) {
            $body['size'] = $size;
        }
        return $this->client->request('POST', '/images/generate', $body);
    }

    /** POST /images/upload */
    public function upload(array $data = []): array
    {
        return $this->client->request('POST', '/images/upload', $data);
    }
}

// ── Resource: Profile ───────────────────────────────────────────────────────────
