#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char *token;
    long long expiresAt;
} MisarTokenResult;

char *misarblog_embed_url(const char *username, const char *slug, const char *theme);
MisarTokenResult *misarblog_refresh_token(const char *token, const char *base_url);
void misarblog_free_token_result(MisarTokenResult *result);
void misarblog_free(char *ptr);

#ifdef __cplusplus
}
#endif
