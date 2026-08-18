<?php

declare(strict_types=1);

namespace MisarBlog\Tests;

use MisarBlog\ApiError;
use MisarBlog\Client;
use MisarBlog\PlanLimitError;
use PHPUnit\Framework\TestCase;

/**
 * Exercises the SDK against a real HTTP server.
 *
 * The client talks cURL directly, so there is no transport to inject a mock
 * into — and mocking one would not test the code that ships. `php -S` serving
 * tests/server/router.php replays the real route shapes instead.
 */
class ClientTest extends TestCase
{
    /** @var resource|null */
    private static $server = null;
    private static int $port = 0;

    public static function setUpBeforeClass(): void
    {
        self::$port = random_int(20000, 60000);
        $router = __DIR__ . '/server/router.php';

        self::$server = proc_open(
            sprintf('exec php -S 127.0.0.1:%d %s', self::$port, escapeshellarg($router)),
            [1 => ['file', '/dev/null', 'w'], 2 => ['file', '/dev/null', 'w']],
            $pipes
        );
        if (!is_resource(self::$server)) {
            self::fail('could not start the test server');
        }

        // Wait for the listener rather than sleeping a fixed amount.
        for ($i = 0; $i < 100; $i++) {
            $sock = @fsockopen('127.0.0.1', self::$port, $errno, $errstr, 0.1);
            if ($sock !== false) {
                fclose($sock);
                return;
            }
            usleep(50_000);
        }
        self::fail('test server never came up');
    }

    public static function tearDownAfterClass(): void
    {
        if (is_resource(self::$server)) {
            proc_terminate(self::$server);
            proc_close(self::$server);
        }
    }

    private function client(string $key = 'mbk_test'): Client
    {
        return new Client($key, sprintf('http://127.0.0.1:%d/blog/v1', self::$port));
    }

    private function hit(string $path): array
    {
        $body = file_get_contents(
            sprintf('http://127.0.0.1:%d%s', self::$port, $path),
            false,
            stream_context_create(['http' => [
                'header' => "Authorization: Bearer mbk_test\r\n",
                'ignore_errors' => true,
            ]])
        );
        return json_decode((string) $body, true) ?: [];
    }

    // ── REST ────────────────────────────────────────────────────────────────

    public function testArticlesListReturnsParsedBody(): void
    {
        $result = $this->client()->articles->list(['limit' => 10]);

        $this->assertSame(1, $result['total']);
        $this->assertSame('hello', $result['articles'][0]['slug']);
        // The parameter must reach the wire, not merely the signature.
        $this->assertSame('10', $result['seen_query']['limit']);
    }

    public function testArticlesGetKeepsAnAwkwardSlugAsOneSegment(): void
    {
        // rawurlencode means a space arrives as %20 and the server sees a single
        // path segment; unencoded it would be a malformed request line.
        $result = $this->client()->articles->get('a b');

        $this->assertSame('a b', $result['slug']);
        $this->assertSame('/blog/v1/articles/a%20b', $result['seen_path']);
    }

    public function testProfileReturnsTheAccount(): void
    {
        $this->assertSame('gulshan', $this->client()->profile->get()['username']);
    }

    public function testPlanReportsTheSubscriptionBehindTheKey(): void
    {
        $result = $this->client()->plan->get();

        $this->assertSame('pro', $result['plan']['slug']);
        $this->assertSame(100, $result['limits']['articles_per_month']);
    }

    public function testCommentsListFiltersByArticleId(): void
    {
        $result = $this->client()->comments->list('a1');

        $this->assertSame(1, $result['total']);
        $this->assertSame('a1', $result['seen_query']['article_id']);
    }

    public function testFollowsStatusPassesTheUserId(): void
    {
        $result = $this->client()->follows->status('u2');

        $this->assertTrue($result['following']);
        $this->assertSame('u2', $result['seen_query']['user_id']);
    }

    // ── Errors ──────────────────────────────────────────────────────────────

    public function testUnauthorizedRaisesApiError(): void
    {
        $this->expectException(ApiError::class);
        $this->expectExceptionCode(401);
        $this->client('wrong-key')->profile->get();
    }

    public function testInsufficientScopeCarriesTheScopeDetail(): void
    {
        try {
            $this->client()->articles->createDraft(['title' => 'x']);
            $this->fail('expected ApiError');
        } catch (ApiError $e) {
            // A 403 naming the missing scope is actionable; a bare "forbidden" is not.
            $this->assertSame(403, $e->status);
            $this->assertSame('articles:write', $e->requiredScope);
            $this->assertContains('articles:read', $e->grantedScopes);
        }
    }

    public function testSpentAllowanceRaisesPlanLimitAndIsNotRetried(): void
    {
        $this->hit('/__reset');

        try {
            $this->client()->articles->publish(['title' => 'x']);
            $this->fail('expected PlanLimitError');
        } catch (PlanLimitError $e) {
            $this->assertSame(429, $e->status);
            $this->assertSame('starter', $e->plan);
            $this->assertSame(3600, $e->retryAfter);
            $this->assertSame('https://www.misar.blog/pricing', $e->upgradeUrl);
        }

        // A spent allowance cannot be fixed by retrying, so exactly one request.
        $this->assertSame(1, $this->hit('/__count')['count']);
    }

    public function testRetriesA503ThenSucceeds(): void
    {
        $this->hit('/__reset');
        $result = $this->client()->search->query(['q' => 'x']);

        $this->assertSame(3, $result['attempts']);
    }
}
