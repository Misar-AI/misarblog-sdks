<?php

declare(strict_types=1);

namespace MisarBlog;

/**
 * A series/collection of articles, per the `Series` schema.
 */
final class Series
{
    public function __construct(
        public readonly ?string $id = null,
        public readonly ?string $slug = null,
        public readonly ?string $title = null,
        public readonly ?string $description = null,
        public readonly ?int $articleCount = null,
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
            description: $json['description'] ?? null,
            articleCount: isset($json['article_count']) ? (int) $json['article_count'] : null,
            createdAt: $json['created_at'] ?? null,
        );
    }
}
