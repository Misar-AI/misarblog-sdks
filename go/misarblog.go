package misarblog

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

const EMBED_BASE = "https://misar.blog"

type TokenResult struct {
	Token     string `json:"token"`
	ExpiresAt int64  `json:"expiresAt"`
}

func EmbedURL(username, slug, theme string) string {
	var path string
	if slug != "" {
		path = fmt.Sprintf("%s/%s/%s/embed", EMBED_BASE, username, slug)
	} else {
		path = fmt.Sprintf("%s/%s/embed", EMBED_BASE, username)
	}
	if theme != "" && theme != "auto" {
		path = fmt.Sprintf("%s?theme=%s", path, theme)
	}
	return path
}

func RefreshToken(token, baseURL string) (*TokenResult, error) {
	payload, err := json.Marshal(map[string]string{"token": token})
	if err != nil {
		return nil, err
	}
	resp, err := http.Post(baseURL+"/api/auth/refresh", "application/json", bytes.NewBuffer(payload))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("refresh failed: %d", resp.StatusCode)
	}
	var result TokenResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}
