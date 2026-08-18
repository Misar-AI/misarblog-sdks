use misarblog::types::{ListArticlesParams, PublishArticleRequest};
use misarblog::{BlogApiError, MisarBlog};
use serde_json::json;
use wiremock::matchers::{header, method, path, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

fn client(server: &MockServer) -> MisarBlog {
    MisarBlog::new("mbk_test").with_base_url(&server.uri())
}

#[tokio::test]
async fn get_article_is_typed_and_authorized() {
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/articles/hello-world"))
        .and(header("authorization", "Bearer mbk_test"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "id": "a1", "slug": "hello-world", "title": "Hello World",
            "status": "published", "url": "https://misar.blog/x/hello-world",
            "editor_url": "https://www.misar.blog/edit/a1",
            "excerpt": null, "tags": ["rust"], "visibility": "public",
            "published_at": "2026-01-01T00:00:00Z", "created_at": "2026-01-01T00:00:00Z"
        })))
        .mount(&server)
        .await;

    let article = client(&server).articles.get("hello-world").await.unwrap();
    assert_eq!(article.slug, "hello-world");
    assert_eq!(article.tags, vec!["rust"]);
}

#[tokio::test]
async fn publish_serializes_typed_body() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/articles"))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({
            "id": "a2", "slug": "my-post", "title": "My Post",
            "status": "published", "url": "u", "editor_url": "e"
        })))
        .mount(&server)
        .await;

    let out = client(&server)
        .articles
        .publish(&PublishArticleRequest {
            title: "My Post".into(),
            body_markdown: "# hi".into(),
            tags: vec!["a".into(), "b".into()],
            ..Default::default()
        })
        .await
        .unwrap();
    assert_eq!(out.slug, "my-post");
}

#[tokio::test]
async fn list_articles_sends_query_params() {
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/articles"))
        .and(query_param("status", "draft"))
        .and(query_param("limit", "5"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(json!({ "articles": [], "total": 0 })),
        )
        .mount(&server)
        .await;

    let params = ListArticlesParams {
        status: Some("draft".into()),
        limit: Some(5),
        ..Default::default()
    };
    let res = client(&server).articles.list(&params).await.unwrap();
    assert_eq!(res["total"], 0);
}

#[tokio::test]
async fn error_envelope_is_parsed() {
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/me"))
        .respond_with(ResponseTemplate::new(401).set_body_json(json!({ "error": "missing key" })))
        .mount(&server)
        .await;

    let err = client(&server).account.me().await.unwrap_err();
    match err {
        BlogApiError::Api { status, message } => {
            assert_eq!(status, 401);
            assert_eq!(message, "missing key");
        }
        other => panic!("expected Api error, got {other:?}"),
    }
}

#[tokio::test]
async fn retries_then_succeeds() {
    let server = MockServer::start().await;
    // First response 503, then 200. With max_retries=3 the client must retry.
    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(ResponseTemplate::new(503))
        .up_to_n_times(1)
        .mount(&server)
        .await;
    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({ "plan": "pro" })))
        .mount(&server)
        .await;

    let res = client(&server).plan.get().await.unwrap();
    assert_eq!(res["plan"], "pro");
}

#[tokio::test]
async fn sends_on_final_attempt_no_off_by_one() {
    // Every attempt returns 429. The client is configured for exactly 2 attempts.
    // A correct implementation SENDS on the final attempt too, so the server
    // must observe exactly 2 requests and the returned error carries the real
    // 429 body — not a synthetic "max retries" placeholder that skipped the send.
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(ResponseTemplate::new(429).set_body_json(json!({ "error": "rate limited" })))
        .expect(2)
        .mount(&server)
        .await;

    let blog = MisarBlog::new("mbk_test")
        .with_base_url(&server.uri())
        .with_max_retries(2);
    let err = blog.plan.get().await.unwrap_err();
    match err {
        BlogApiError::Api { status, message } => {
            assert_eq!(status, 429);
            assert_eq!(message, "rate limited");
        }
        other => panic!("expected Api 429, got {other:?}"),
    }
    // Mock `.expect(2)` is verified on drop — confirms the final attempt was sent.
}
