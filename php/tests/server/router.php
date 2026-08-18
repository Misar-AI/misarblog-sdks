<?php
/**
 * Canned Misar.Blog API for the SDK tests, served by `php -S`.
 *
 * The client talks cURL directly, so there is no injectable transport to mock —
 * and mocking one would test a transport that does not ship. This replays the
 * real response shapes instead, including the plan-limit envelope and the 403
 * scope detail.
 */
declare(strict_types=1);

$path    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/';
$counter = sys_get_temp_dir() . '/misarblog-test-counter';

function json(int $status, array $body, array $headers = []): void
{
    http_response_code($status);
    header('Content-Type: application/json');
    foreach ($headers as $k => $v) {
        header("$k: $v");
    }
    echo json_encode($body);
}

if (($_SERVER['HTTP_AUTHORIZATION'] ?? '') !== 'Bearer mbk_test') {
    json(401, ['error' => 'unauthorized']);
    return;
}

switch (true) {
    case $path === '/blog/v1/articles' && $_SERVER['REQUEST_METHOD'] === 'GET':
        json(200, [
            'articles' => [['slug' => 'hello', 'title' => 'Hello']],
            'total'    => 1,
            // Echoed so a test can prove the query reached the server.
            'seen_query' => $_GET,
        ]);
        return;

    // A slug needing encoding. php -S reports REQUEST_URI undecoded, so matching
    // the %20 form is itself the proof that rawurlencode was applied — an
    // unencoded space would have produced a malformed request line instead.
    case $path === '/blog/v1/articles/a%20b':
        json(200, ['slug' => 'a b', 'seen_path' => $path]);
        return;

    case $path === '/blog/v1/me':
        json(200, ['id' => 'u1', 'username' => 'gulshan']);
        return;

    case $path === '/blog/v1/plan':
        json(200, ['plan' => ['slug' => 'pro'], 'limits' => ['articles_per_month' => 100]]);
        return;

    case $path === '/blog/v1/comments':
        json(200, ['comments' => [['id' => 'c1']], 'total' => 1, 'seen_query' => $_GET]);
        return;

    case $path === '/blog/v1/follows':
        json(200, ['following' => true, 'seen_query' => $_GET]);
        return;

    // A spent allowance: 429 carrying the plan-limit envelope.
    case $path === '/blog/v1/articles' && $_SERVER['REQUEST_METHOD'] === 'POST':
        file_put_contents($counter, (string) (((int) @file_get_contents($counter)) + 1));
        json(429, [
            'code'    => 'plan_limit_exceeded',
            'error'   => 'monthly article allowance spent',
            'upgrade' => ['urls' => ['pricing' => 'https://www.misar.blog/pricing']],
        ], ['X-Misar-Plan' => 'starter', 'Retry-After' => '3600']);
        return;

    // A 403 that names the scope the key is missing.
    case $path === '/blog/v1/drafts':
        json(403, [
            'error'          => 'insufficient scope',
            'required_scope' => 'articles:write',
            'granted_scopes' => ['articles:read'],
        ]);
        return;

    // Two 503s then a 200 — the retry path.
    case $path === '/blog/v1/search':
        $n = (int) @file_get_contents($counter);
        file_put_contents($counter, (string) ($n + 1));
        if ($n < 2) {
            json(503, ['error' => 'unavailable']);
            return;
        }
        json(200, ['results' => [], 'attempts' => $n + 1]);
        return;

    case $path === '/__count':
        json(200, ['count' => (int) @file_get_contents($counter)]);
        return;

    case $path === '/__reset':
        @unlink($counter);
        json(200, ['ok' => true]);
        return;

    default:
        json(404, ['error' => "no route for $path"]);
}
