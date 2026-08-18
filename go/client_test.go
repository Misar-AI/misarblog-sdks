package misarblog_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	misarblog "github.com/Misar-AI/misarblog-sdks/go"
)

func newTestClient(server *httptest.Server) *misarblog.Client {
	return misarblog.New("mbk_test",
		misarblog.WithBaseURL(server.URL),
		misarblog.WithMaxRetries(3),
		misarblog.WithHTTPClient(server.Client()),
	)
}

func TestGetProfile(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/me" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer mbk_test" {
			t.Errorf("bad auth header: %s", got)
		}
		json.NewEncoder(w).Encode(map[string]any{"id": "u1", "username": "gulshan"})
	}))
	defer srv.Close()

	me, err := newTestClient(srv).Me.Get(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if me.Username != "gulshan" {
		t.Errorf("expected username gulshan, got %s", me.Username)
	}
}

func TestListArticlesQuery(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/articles" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		if r.URL.Query().Get("status") != "published" {
			t.Errorf("expected status=published, got %s", r.URL.Query().Get("status"))
		}
		if r.URL.Query().Get("limit") != "5" {
			t.Errorf("expected limit=5, got %s", r.URL.Query().Get("limit"))
		}
		json.NewEncoder(w).Encode(map[string]any{"articles": []any{}, "total": 0})
	}))
	defer srv.Close()

	res, err := newTestClient(srv).Articles.List(context.Background(), &misarblog.ListArticlesParams{
		Status: "published", Limit: 5,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Total != 0 {
		t.Errorf("expected total 0, got %d", res.Total)
	}
}

func TestPublishArticle(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/articles" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		var body map[string]any
		json.NewDecoder(r.Body).Decode(&body)
		if body["title"] != "Hello" {
			t.Errorf("expected title Hello, got %v", body["title"])
		}
		json.NewEncoder(w).Encode(map[string]any{"id": "a1", "slug": "hello", "status": "published"})
	}))
	defer srv.Close()

	res, err := newTestClient(srv).Articles.Publish(context.Background(), &misarblog.PublishArticleRequest{
		Title: "Hello", BodyMarkdown: "# Hi",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Slug != "hello" {
		t.Errorf("expected slug hello, got %s", res.Slug)
	}
}

func TestReactionsRemove(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete || r.URL.Path != "/reactions" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		if r.URL.Query().Get("article_id") != "a1" || r.URL.Query().Get("type") != "clap" {
			t.Errorf("bad query: %s", r.URL.RawQuery)
		}
		json.NewEncoder(w).Encode(map[string]any{"success": true, "reacted": false})
	}))
	defer srv.Close()

	res, err := newTestClient(srv).Reactions.Remove(context.Background(), "a1", "clap")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !res.Success {
		t.Error("expected success true")
	}
}

func TestSeriesAddArticlePath(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/series/my-series/articles" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		json.NewEncoder(w).Encode(map[string]any{"ok": true})
	}))
	defer srv.Close()

	out, err := newTestClient(srv).Series.AddArticle(context.Background(), "my-series", &misarblog.AddToSeriesRequest{
		ArticleSlug: "some-slug",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out["ok"] != true {
		t.Errorf("expected ok true, got %v", out["ok"])
	}
}

func TestImageUploadMultipart(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/images/upload" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		if ct := r.Header.Get("Content-Type"); !strings.HasPrefix(ct, "multipart/form-data") {
			t.Errorf("expected multipart content-type, got %s", ct)
		}
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Errorf("parse multipart: %v", err)
		}
		f, _, err := r.FormFile("file")
		if err != nil {
			t.Errorf("missing file field: %v", err)
		} else {
			f.Close()
		}
		json.NewEncoder(w).Encode(map[string]any{"url": "https://cdn/x.png"})
	}))
	defer srv.Close()

	out, err := newTestClient(srv).Images.Upload(context.Background(), "x.png", []byte("PNGDATA"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out["url"] != "https://cdn/x.png" {
		t.Errorf("expected url, got %v", out["url"])
	}
}

func TestAPIError403Scope(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(map[string]any{
			"error":          "insufficient scope",
			"required_scope": "articles:write",
			"granted_scopes": []string{"articles:read"},
		})
	}))
	defer srv.Close()

	_, err := newTestClient(srv).Articles.Publish(context.Background(), &misarblog.PublishArticleRequest{
		Title: "x", BodyMarkdown: "y",
	})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	apiErr, ok := err.(*misarblog.APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.Status != 403 {
		t.Errorf("expected status 403, got %d", apiErr.Status)
	}
	if apiErr.RequiredScope != "articles:write" {
		t.Errorf("expected required_scope articles:write, got %s", apiErr.RequiredScope)
	}
	if len(apiErr.GrantedScopes) != 1 || apiErr.GrantedScopes[0] != "articles:read" {
		t.Errorf("unexpected granted_scopes: %v", apiErr.GrantedScopes)
	}
}

func TestRetry503ThenSuccess(t *testing.T) {
	var counter atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := counter.Add(1)
		if n < 3 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"id": "u1", "username": "ok"})
	}))
	defer srv.Close()

	me, err := newTestClient(srv).Me.Get(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if me.Username != "ok" {
		t.Errorf("expected username ok, got %s", me.Username)
	}
	if counter.Load() != 3 {
		t.Errorf("expected 3 attempts, got %d", counter.Load())
	}
}

func TestRetryExhausted(t *testing.T) {
	var counter atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		counter.Add(1)
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	_, err := newTestClient(srv).Me.Get(context.Background())
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	apiErr, ok := err.(*misarblog.APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.Status != 503 {
		t.Errorf("expected status 503, got %d", apiErr.Status)
	}
	if counter.Load() != 3 {
		t.Errorf("expected exactly 3 attempts (no off-by-one), got %d", counter.Load())
	}
}
