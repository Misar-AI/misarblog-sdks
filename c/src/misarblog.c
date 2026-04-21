#include "misarblog.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>

#define EMBED_BASE "https://misar.blog"

typedef struct {
    char *data;
    size_t size;
} Buffer;

static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    Buffer *buf = (Buffer *)userp;
    char *ptr = realloc(buf->data, buf->size + realsize + 1);
    if (!ptr) return 0;
    buf->data = ptr;
    memcpy(buf->data + buf->size, contents, realsize);
    buf->size += realsize;
    buf->data[buf->size] = '\0';
    return realsize;
}

char *misarblog_embed_url(const char *username, const char *slug, const char *theme) {
    char *url = malloc(512);
    if (!url) return NULL;
    if (slug && *slug) {
        snprintf(url, 512, "%s/%s/%s/embed", EMBED_BASE, username, slug);
    } else {
        snprintf(url, 512, "%s/%s/embed", EMBED_BASE, username);
    }
    if (theme && *theme && strcmp(theme, "auto") != 0) {
        size_t len = strlen(url);
        snprintf(url + len, 512 - len, "?theme=%s", theme);
    }
    return url;
}

MisarTokenResult *misarblog_refresh_token(const char *token, const char *base_url) {
    char url[512];
    snprintf(url, sizeof(url), "%s/api/auth/refresh", base_url ? base_url : EMBED_BASE);

    char body[1024];
    snprintf(body, sizeof(body), "{\"token\":\"%s\"}", token);

    Buffer buf = { .data = calloc(1, 1), .size = 0 };
    if (!buf.data) return NULL;

    CURL *curl = curl_easy_init();
    if (!curl) { free(buf.data); return NULL; }

    struct curl_slist *headers = curl_slist_append(NULL, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);

    CURLcode res = curl_easy_perform(curl);
    long status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK || status != 200) { free(buf.data); return NULL; }

    /* parse token field */
    MisarTokenResult *result = malloc(sizeof(MisarTokenResult));
    if (!result) { free(buf.data); return NULL; }

    const char *tok_key = "\"token\":\"";
    char *tok_start = strstr(buf.data, tok_key);
    if (tok_start) {
        tok_start += strlen(tok_key);
        char *tok_end = strchr(tok_start, '"');
        size_t tok_len = tok_end ? (size_t)(tok_end - tok_start) : 0;
        result->token = malloc(tok_len + 1);
        if (result->token) { memcpy(result->token, tok_start, tok_len); result->token[tok_len] = '\0'; }
    } else {
        result->token = NULL;
    }

    const char *exp_key = "\"expiresAt\":";
    char *exp_start = strstr(buf.data, exp_key);
    result->expiresAt = exp_start ? atoll(exp_start + strlen(exp_key)) : 0;

    free(buf.data);
    return result;
}

void misarblog_free_token_result(MisarTokenResult *result) {
    if (!result) return;
    free(result->token);
    free(result);
}

void misarblog_free(char *ptr) {
    free(ptr);
}
