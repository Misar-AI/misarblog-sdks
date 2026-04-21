<?php

namespace MisarBlog;

class Embed
{
    public const EMBED_BASE = 'https://misar.blog';

    public static function url(string $username, ?string $slug = null, string $theme = 'auto'): string
    {
        $url = self::EMBED_BASE . '/' . $username;
        if ($slug !== null && $slug !== '') {
            $url .= '/' . $slug;
        }
        $url .= '/embed';
        if ($theme !== 'auto') {
            $url .= '?theme=' . urlencode($theme);
        }
        return $url;
    }
}
