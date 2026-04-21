#pragma once
#include <string>

namespace misarblog {

const std::string EMBED_BASE = "https://misar.blog";

struct TokenResult {
    std::string token;
    long long expiresAt;
};

std::string embedUrl(const std::string &username, const std::string &slug = "", const std::string &theme = "auto");
TokenResult refreshToken(const std::string &token, const std::string &baseUrl = EMBED_BASE);

} // namespace misarblog
