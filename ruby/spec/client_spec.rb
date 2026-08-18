require "spec_helper"

RSpec.describe MisarBlog::Client do
  let(:base_url) { "https://api.misar.io/blog/v1" }
  let(:client) { described_class.new(api_key: "mbk_test", base_url: base_url, max_retries: 1) }

  # Matches the path with or without a query string. webmock compares query
  # strings strictly, so an exact-URL stub silently failed to match any call that
  # passed a parameter — `articles.list(limit: 10)` requests `/articles?limit=10`.
  def stub_verb(verb, path, status:, body:)
    pattern = %r{\A#{Regexp.escape("#{base_url}#{path}")}(\?|\z)}
    stub_request(verb, pattern)
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "sends the mbk_ bearer token" do
    stub = stub_request(:get, "#{base_url}/me")
           .with(headers: { "Authorization" => "Bearer mbk_test" })
           .to_return(status: 200, body: { "id" => "u1", "username" => "gulshan" }.to_json)
    client.account.profile
    expect(stub).to have_been_requested
  end

  it "articles.list returns typed ArticleList" do
    stub_verb(:get, "/articles", status: 200,
              body: { "articles" => [{ "id" => "a1", "slug" => "hello", "title" => "Hello" }], "total" => 1 })
    result = client.articles.list(limit: 10)
    expect(result).to be_a(MisarBlog::Models::ArticleList)
    expect(result.total).to eq(1)
    expect(result.articles.first).to be_a(MisarBlog::Models::Article)
    expect(result.articles.first.slug).to eq("hello")
  end

  it "articles.get returns a typed Article" do
    stub_verb(:get, "/articles/hello", status: 200,
              body: { "id" => "a1", "slug" => "hello", "title" => "Hello", "status" => "published" })
    article = client.articles.get("hello")
    expect(article.title).to eq("Hello")
    expect(article.status).to eq("published")
  end

  it "articles.publish posts to /articles" do
    stub_verb(:post, "/articles", status: 200,
              body: { "id" => "a2", "slug" => "new-post", "status" => "published" })
    article = client.articles.publish(title: "New Post", body_markdown: "# Hi")
    expect(article.slug).to eq("new-post")
  end

  it "ai.titles returns typed TitlesResult" do
    stub_verb(:post, "/ai/titles", status: 200,
              body: { "titles" => [{ "title" => "T1", "hint" => "h" }] })
    res = client.ai.titles(action: "seo", prompt: "ai blogging")
    expect(res.titles.first.title).to eq("T1")
  end

  it "reactions.add posts and returns ReactionResult" do
    stub_verb(:post, "/reactions", status: 200, body: { "success" => true, "reacted" => true })
    res = client.reactions.add(article_id: "a1", type: "like")
    expect(res.success).to be true
  end

  it "reactions.remove deletes with query params" do
    stub = stub_request(:delete, "#{base_url}/reactions?article_id=a1&type=like")
           .to_return(status: 200, body: { "success" => true, "reacted" => false }.to_json)
    res = client.reactions.remove(article_id: "a1", type: "like")
    expect(stub).to have_been_requested
    expect(res.reacted).to be false
  end

  it "analytics.get returns typed Analytics" do
    stub_verb(:get, "/analytics", status: 200,
              body: { "period_days" => 30, "views" => 1000, "revenue_cents" => 500 })
    res = client.analytics.get(days: 30)
    expect(res.views).to eq(1000)
    expect(res.revenue_cents).to eq(500)
  end

  it "raises ApiError on 401 with status" do
    stub_verb(:get, "/me", status: 401, body: { "error" => "Unauthorized" })
    expect { client.account.profile }
      .to raise_error(MisarBlog::ApiError) { |e| expect(e.status).to eq(401) }
  end

  it "retries on 503 and still succeeds on the final attempt" do
    retry_client = described_class.new(api_key: "mbk_k", base_url: base_url, max_retries: 3)
    allow(retry_client).to receive(:sleep)
    stub_request(:get, "#{base_url}/me").to_return(
      { status: 503, body: { "error" => "down" }.to_json, headers: { "Content-Type" => "application/json" } },
      { status: 503, body: { "error" => "down" }.to_json, headers: { "Content-Type" => "application/json" } },
      { status: 200, body: { "id" => "u1", "username" => "ok" }.to_json, headers: { "Content-Type" => "application/json" } }
    )
    profile = retry_client.account.profile
    expect(profile.username).to eq("ok")
  end

  it "raises NetworkError on connection failure" do
    stub_request(:get, "#{base_url}/me").to_raise(SocketError.new("refused"))
    expect { client.account.profile }.to raise_error(MisarBlog::NetworkError)
  end

  # Regression: parse_response short-circuited on an empty body *before* looking at
  # the status, so an error with nothing in it returned {} and read as success. A
  # bare 401 and anything a proxy strips both arrive this way.
  [401, 403, 404].each do |code|
    it "raises on #{code} even when the body is empty" do
      stub_request(:get, "#{base_url}/me").to_return(status: code, body: "")
      expect { client.account.profile }
        .to raise_error(MisarBlog::ApiError) { |e| expect(e.status).to eq(code) }
    end
  end

  it "still returns {} for a successful empty body" do
    stub_request(:get, "#{base_url}/me").to_return(status: 204, body: "")
    expect(client.send(:request, :get, "/me")).to eq({})
  end
end
