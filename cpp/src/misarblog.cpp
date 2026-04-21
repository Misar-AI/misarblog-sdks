#include "misarblog.hpp"
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <stdexcept>
#include <sstream>

using json = nlohmann::json;

namespace misarblog {

static size_t writeCallback(void *contents, size_t size, size_t nmemb, std::string *s) {
    s->append(static_cast<char *>(contents), size * nmemb);
    return size * nmemb;
}

std::string embedUrl(const std::string &username, const std::string &slug, const std::string &theme) {
    std::string url = EMBED_BASE + "/" + username;
    if (!slug.empty()) url += "/" + slug;
    url += "/embed";
    if (!theme.empty() && theme != "auto") url += "?theme=" + theme;
    return url;
}

TokenResult refreshToken(const std::string &token, const std::string &baseUrl) {
    std::string url = baseUrl + "/api/auth/refresh";
    std::string body = json{{"token", token}}.dump();
    std::string response;

    CURL *curl = curl_easy_init();
    if (!curl) throw std::runtime_error("curl_easy_init failed");

    struct curl_slist *headers = curl_slist_append(nullptr, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

    CURLcode res = curl_easy_perform(curl);
    long status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) throw std::runtime_error(curl_easy_strerror(res));
    if (status != 200) throw std::runtime_error("HTTP error: " + std::to_string(status));

    auto j = json::parse(response);
    return TokenResult{j.at("token").get<std::string>(), j.at("expiresAt").get<long long>()};
}

} // namespace misarblog
