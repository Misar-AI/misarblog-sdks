<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * GET /comments — an article's comment thread.
 */
class CommentsResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * List an article's comments, newest first, replies nested one level deep.
     *
     * @param int|null $limit  1..100; defaults to 20 server-side
     * @param int|null $offset defaults to 0 server-side
     * @return array<string,mixed>
     */
    public function list(string $articleId, ?int $limit = null, ?int $offset = null): array
    {
        $q = ['article_id' => $articleId];
        if ($limit !== null) {
            $q['limit'] = $limit;
        }
        if ($offset !== null) {
            $q['offset'] = $offset;
        }

        return $this->client->request('GET', '/comments?' . http_build_query($q));
    }
}
