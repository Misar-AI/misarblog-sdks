<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * A blog article, per the OpenAPI `Article` schema. The dev API returns plain
 * JSON; resource methods hand back the decoded associative array. Use
 * {@see Article::from()} for a typed view.
 */
final class Article
{
    /**
     * @param list<string> $tags
     */
    public function __construct(
        public readonly ?string $id = null,
        public readonly ?string $slug = null,
        public readonly ?string $title = null,
        public readonly ?string $status = null,
        public readonly ?string $url = null,
        public readonly ?string $editorUrl = null,
        public readonly ?string $excerpt = null,
        public readonly array $tags = [],
        public readonly ?string $visibility = null,
        public readonly ?string $publishedAt = null,
        public readonly ?string $createdAt = null,
    ) {}

    /**
     * @param array<string,mixed> $json
     */
    public static function from(array $json): self
    {
        return new self(
            id: $json['id'] ?? null,
            slug: $json['slug'] ?? null,
            title: $json['title'] ?? null,
            status: $json['status'] ?? null,
            url: $json['url'] ?? null,
            editorUrl: $json['editor_url'] ?? null,
            excerpt: $json['excerpt'] ?? null,
            tags: is_array($json['tags'] ?? null) ? $json['tags'] : [],
            visibility: $json['visibility'] ?? null,
            publishedAt: $json['published_at'] ?? null,
            createdAt: $json['created_at'] ?? null,
        );
    }
}
