<?php

declare(strict_types=1);

namespace MisarBlog;

class AiResource
{
    public function __construct(private readonly Client $client) {}

    /** POST /ai/complete */
    public function complete(string $prompt, ?string $system = null, ?int $maxTokens = null): array
    {
        $body = ['prompt' => $prompt];
        if ($system !== null) {
            $body['system'] = $system;
        }
        if ($maxTokens !== null) {
            $body['max_tokens'] = $maxTokens;
        }
        return $this->client->request('POST', '/ai/complete', $body);
    }

    /** POST /ai/titles */
    public function titles(string $action, ?string $prompt = null, ?string $context = null): array
    {
        $body = ['action' => $action];
        if ($prompt !== null) {
            $body['prompt'] = $prompt;
        }
        if ($context !== null) {
            $body['context'] = $context;
        }
        return $this->client->request('POST', '/ai/titles', $body);
    }
}

// ── Resource: Articles ──────────────────────────────────────────────────────────
