<?php

namespace MisarBlog;

class Auth
{
    public static function refreshToken(string $token, string $baseUrl = 'https://misar.blog'): array
    {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $baseUrl . '/api/auth/refresh');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode(['token' => $token]));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

        $response = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($status !== 200) {
            throw new \RuntimeException("Refresh failed with status: $status");
        }

        return json_decode($response, true);
    }
}
