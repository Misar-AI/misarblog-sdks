<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * Client for the Misar.Blog developer API (https://api.misar.io/blog/v1).
 *
 * Authenticate with a Misar.Blog developer key (mbk_...) or an OAuth 2.1 access
 * token — both are sent as `Authorization: Bearer <key>`.
 *
 * Each call performs up to MAX_RETRIES attempts with exponential back-off
 * (starting at RETRY_BASE_MS) on retryable HTTP statuses (429, 500, 502, 503,
 * 504). The final attempt is always sent and its response returned/thrown.
 *
 * Plain request/response JSON — every operation on the keyed developer surface
 * is a single request. The API exposes no SSE endpoint that accepts an API key
 * (the streaming routes are cookie-session or MCP transport), so there is
 * nothing to stream here. Rate limit:
 * 100 requests/minute.
 */
class Client
{
    public readonly AiResource             $ai;
    public readonly ArticlesResource       $articles;
    public readonly ImagesResource         $images;
    public readonly ProfileResource        $profile;
    public readonly PlanResource           $plan;
    public readonly ReactionsResource      $reactions;
    public readonly RecommendationsResource $recommendations;
    public readonly SearchResource         $search;
    public readonly SeriesResource         $series;
    public readonly TrialResource          $trial;
    public readonly AnalyticsResource      $analytics;
    public readonly UpsellResource         $upsell;
    public readonly CommentsResource       $comments;
    public readonly FollowsResource        $follows;

    private const BASE_URL      = 'https://api.misar.io/blog/v1';
    private const RETRYABLE     = [429, 500, 502, 503, 504];
    private const RETRY_BASE_MS = 500;
    private const MAX_RETRIES   = 3;

    private readonly string $baseUrl;

    public function __construct(
        private readonly string $apiKey,
        ?string $baseUrl = null,
        private readonly int $timeout = 30,
    ) {
        $this->baseUrl = rtrim($baseUrl ?? self::BASE_URL, '/');

        $this->ai              = new AiResource($this);
        $this->articles        = new ArticlesResource($this);
        $this->images          = new ImagesResource($this);
        $this->profile         = new ProfileResource($this);
        $this->plan            = new PlanResource($this);
        $this->reactions       = new ReactionsResource($this);
        $this->recommendations = new RecommendationsResource($this);
        $this->search          = new SearchResource($this);
        $this->series          = new SeriesResource($this);
        $this->trial           = new TrialResource($this);
        $this->analytics       = new AnalyticsResource($this);
        $this->upsell          = new UpsellResource($this);
        $this->comments        = new CommentsResource($this);
        $this->follows         = new FollowsResource($this);
    }

    /** True when an error body carries the API's plan-limit code. */
    private static function isPlanLimit(string $body): bool
    {
        if ($body === '') {
            return false;
        }
        $decoded = json_decode($body, true);

        return is_array($decoded) && ($decoded['code'] ?? null) === 'plan_limit_exceeded';
    }

    /**
     * @param array<string,mixed> $data
     * @return array<string,mixed>
     * @throws ApiError
     * @throws NetworkError
     */
    public function request(string $method, string $path, array $data = []): array
    {
        $url      = $this->baseUrl . '/' . ltrim($path, '/');
        $hasBody  = $data !== [] && in_array($method, ['POST', 'PUT', 'PATCH'], true);
        $jsonBody = $hasBody ? json_encode($data, JSON_THROW_ON_ERROR) : null;
        // POST with an empty body still needs a JSON object payload.
        if ($jsonBody === null && $method === 'POST') {
            $jsonBody = '{}';
        }

        $headers = [
            'Authorization: Bearer ' . $this->apiKey,
            'Content-Type: application/json',
            'Accept: application/json',
        ];

        $lastStatus = 0;

        for ($attempt = 0; $attempt < self::MAX_RETRIES; $attempt++) {
            if ($attempt > 0) {
                usleep(self::RETRY_BASE_MS * (1 << ($attempt - 1)) * 1000);
            }

            $respHeaders = [];
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL            => $url,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER     => $headers,
                CURLOPT_CUSTOMREQUEST  => $method,
                CURLOPT_TIMEOUT        => $this->timeout,
                CURLOPT_CONNECTTIMEOUT => 10,
                CURLOPT_FOLLOWLOCATION => false,
                // The plan-refusal offer arrives in headers as well as the
                // body, so collect them rather than discarding the header block.
                CURLOPT_HEADERFUNCTION => function ($_ch, string $line) use (&$respHeaders): int {
                    $parts = explode(':', $line, 2);
                    if (count($parts) === 2) {
                        $respHeaders[strtolower(trim($parts[0]))] = trim($parts[1]);
                    }
                    return strlen($line);
                },
            ]);
            if ($jsonBody !== null) {
                curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonBody);
            }

            $body      = curl_exec($ch);
            $curlErrno = curl_errno($ch);
            $curlError = curl_error($ch);
            $status    = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($curlErrno !== 0) {
                if ($attempt < self::MAX_RETRIES - 1) {
                    continue;
                }
                throw new NetworkError("cURL error ({$curlErrno}): {$curlError}");
            }

            $lastStatus = $status;

            // Retry retryable statuses only while attempts remain; the final
            // attempt falls through and surfaces the real response.
            // A plan-limit 429 is not "slow down": retrying cannot help until
            // the allowance resets or the plan changes, so fall through and
            // raise instead of burning the retry budget.
            if (in_array($status, self::RETRYABLE, true)
                && $attempt < self::MAX_RETRIES - 1
                && !self::isPlanLimit((string) $body)
            ) {
                continue;
            }

            // Only a *successful* empty body means "no content". An error with an
            // empty body — a bare 401, or anything a proxy stripped — must still
            // raise, or the caller reads a failure as an empty result set.
            if ($status < 400 && ($status === 204 || $body === '' || $body === false)) {
                return [];
            }

            $decoded = json_decode((string) $body, true);

            if ($status >= 400) {
                $message       = 'error';
                $requiredScope = null;
                $grantedScopes = [];
                if (is_array($decoded)) {
                    $message       = (string) ($decoded['error'] ?? $decoded['message'] ?? $body);
                    $requiredScope = isset($decoded['required_scope']) ? (string) $decoded['required_scope'] : null;
                    $grantedScopes = is_array($decoded['granted_scopes'] ?? null) ? $decoded['granted_scopes'] : [];
                } else {
                    $message = (string) $body;
                }
                // A stripped body leaves nothing to report; name the status so the
                // exception still says something useful.
                if ($message === '') {
                    $message = "HTTP {$status}";
                }
                if (is_array($decoded) && ($decoded['code'] ?? null) === 'plan_limit_exceeded') {
                    $offer = is_array($decoded['upgrade'] ?? null) ? $decoded['upgrade'] : [];
                    // Headers are authoritative; fall back to the offer body
                    // when a proxy has stripped them.
                    $upgradeUrl = $respHeaders['x-misar-upgrade-url'] ?? ($offer['urls']['pricing'] ?? null);
                    $plan       = $respHeaders['x-misar-plan'] ?? ($offer['current_plan']['slug'] ?? null);
                    $retryAfter = isset($respHeaders['retry-after']) && ctype_digit($respHeaders['retry-after'])
                        ? (int) $respHeaders['retry-after']
                        : null;

                    throw new PlanLimitError(
                        $message,
                        $status,
                        $plan !== null ? (string) $plan : null,
                        $upgradeUrl !== null ? (string) $upgradeUrl : null,
                        $retryAfter,
                        $offer,
                    );
                }

                throw new ApiError($message, $status, $requiredScope, $grantedScopes);
            }

            return is_array($decoded) ? $decoded : [];
        }

        throw new NetworkError("max retries exceeded (last status {$lastStatus})");
    }
}
