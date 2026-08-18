require "net/http"
require "uri"
require "json"

require_relative "errors"
require_relative "models"

module MisarBlog
  # Base URL for the Misar.Blog dev-API. The gateway strips `/api`, so the
  # public base is `https://api.misar.io/blog/v1` (never add `/api`).
  BASE_URL     = "https://api.misar.io/blog/v1".freeze
  RETRYABLE    = [429, 500, 502, 503, 504].freeze
  RETRY_BASE_S = 0.3

  # ── Resource base ────────────────────────────────────────────────────────────

  class Resource
    def initialize(client)
      @client = client
    end

    private

    # Drop nil values so optional params are never serialized.
    def compact(hash)
      hash.reject { |_, v| v.nil? }
    end

    def query(params)
      compacted = compact(params)
      compacted.empty? ? "" : "?#{URI.encode_www_form(compacted)}"
    end
  end

  # ── Resource: AI ─────────────────────────────────────────────────────────────

  class AiResource < Resource
    # POST /ai/complete — free-form completion.
    def complete(prompt:, system: nil, max_tokens: nil)
      body = compact(system: system, prompt: prompt, max_tokens: max_tokens)
      Models::AiText.new(@client.request(:post, "/ai/complete", body))
    end

    # POST /ai/titles — SEO/AEO/GEO title suggestions.
    # action: "suggest" | "seo"
    def titles(action:, prompt: nil, context: nil)
      body = compact(action: action, prompt: prompt, context: context)
      Models::TitlesResult.new(@client.request(:post, "/ai/titles", body))
    end
  end

  # ── Resource: Articles ───────────────────────────────────────────────────────

  class ArticlesResource < Resource
    # GET /articles
    def list(status: nil, visibility: nil, webhook_only: nil, sort: nil, limit: nil)
      qs = query(status: status, visibility: visibility,
                 webhook_only: webhook_only, sort: sort, limit: limit)
      Models::ArticleList.new(@client.request(:get, "/articles#{qs}"))
    end

    # GET /articles/{slug}
    def get(slug)
      Models::Article.new(@client.request(:get, "/articles/#{escape(slug)}"))
    end

    # POST /articles — publish (or schedule) a new article.
    def publish(title:, body_markdown:, tags: nil, cover_image_url: nil,
                schedule_at: nil, visibility: nil)
      body = compact(title: title, body_markdown: body_markdown, tags: tags,
                     cover_image_url: cover_image_url, schedule_at: schedule_at,
                     visibility: visibility)
      Models::Article.new(@client.request(:post, "/articles", body))
    end

    # PATCH /articles/{slug} — update an existing article.
    def update(slug, title: nil, body_markdown: nil, tags: nil, publish: nil)
      body = compact(title: title, body_markdown: body_markdown,
                     tags: tags, publish: publish)
      Models::Article.new(@client.request(:patch, "/articles/#{escape(slug)}", body))
    end

    # POST /drafts — create an unpublished draft.
    def create_draft(title:, body_markdown:, tags: nil)
      body = compact(title: title, body_markdown: body_markdown, tags: tags)
      Models::Article.new(@client.request(:post, "/drafts", body))
    end

    # GET /search — full-text search across articles/profiles/tags.
    def search(q: nil, type: nil, tag: nil, author: nil, sort: nil,
               from: nil, to: nil, limit: nil)
      qs = query(q: q, type: type, tag: tag, author: author, sort: sort,
                 from: from, to: to, limit: limit)
      @client.request(:get, "/search#{qs}")
    end

    # GET /recommendations — related articles for a given article.
    def recommendations(article_id:, limit: nil)
      qs = query(article_id: article_id, limit: limit)
      @client.request(:get, "/recommendations#{qs}")
    end

    private

    def escape(value)
      URI.encode_www_form_component(value.to_s)
    end
  end

  # ── Resource: Images ─────────────────────────────────────────────────────────

  class ImagesResource < Resource
    # POST /images/generate — AI cover-image generation.
    def generate(prompt:, size: nil)
      body = compact(prompt: prompt, size: size)
      Models::ImageResult.new(@client.request(:post, "/images/generate", body))
    end

    # POST /images/upload — register/host an image. Accepts a raw payload Hash.
    def upload(data = {})
      Models::ImageResult.new(@client.request(:post, "/images/upload", data))
    end
  end

  # ── Resource: Reactions ──────────────────────────────────────────────────────

  class ReactionsResource < Resource
    # GET /reactions?article_id=
    def get(article_id:)
      qs = query(article_id: article_id)
      Models::ArticleReactions.new(@client.request(:get, "/reactions#{qs}"))
    end

    # POST /reactions
    def add(article_id:, type:)
      body = compact(article_id: article_id, type: type)
      Models::ReactionResult.new(@client.request(:post, "/reactions", body))
    end

    # DELETE /reactions?article_id=&type=
    def remove(article_id:, type:)
      qs = query(article_id: article_id, type: type)
      Models::ReactionResult.new(@client.request(:delete, "/reactions#{qs}"))
    end
  end

  # ── Resource: Series ─────────────────────────────────────────────────────────

  class SeriesResource < Resource
    # GET /series
    def list
      Models::SeriesList.new(@client.request(:get, "/series"))
    end

    # POST /series
    def create(title:, description: nil)
      body = compact(title: title, description: description)
      Models::Series.new(@client.request(:post, "/series", body))
    end

    # POST /series/{slug}/articles — add an article to a series.
    def add_article(slug, article_slug:, position: nil)
      body = compact(article_slug: article_slug, position: position)
      @client.request(:post, "/series/#{escape(slug)}/articles", body)
    end

    private

    def escape(value)
      URI.encode_www_form_component(value.to_s)
    end
  end

  # ── Resource: Account ────────────────────────────────────────────────────────

  class AccountResource < Resource
    # GET /me
    def profile
      Models::Profile.new(@client.request(:get, "/me"))
    end

    # GET /plan
    def plan
      Models::Plan.new(@client.request(:get, "/plan"))
    end

    # GET /trial
    def trial_status
      Models::TrialStatus.new(@client.request(:get, "/trial"))
    end

    # POST /trial — start a trial for a gated feature.
    def start_trial(feature: nil, ref: nil)
      body = compact(feature: feature, ref: ref)
      @client.request(:post, "/trial", body)
    end

    # GET /upsell-funnel
    def upsell_funnel(days: nil, feature: nil)
      qs = query(days: days, feature: feature)
      @client.request(:get, "/upsell-funnel#{qs}")
    end
  end

  # ── Resource: Analytics ──────────────────────────────────────────────────────

  class AnalyticsResource < Resource
    # GET /analytics
    def get(days: nil)
      qs = query(days: days)
      Models::Analytics.new(@client.request(:get, "/analytics#{qs}"))
    end
  end

  # ── Main Client ──────────────────────────────────────────────────────────────

  # GET /comments — an article's comment thread.
  class CommentsResource < Resource
    # List an article's comments, newest first, replies nested one level deep.
    # @param article_id [String]
    # @param limit  [Integer, nil] 1..100, defaults to 20 server-side
    # @param offset [Integer, nil] defaults to 0 server-side
    def list(article_id:, limit: nil, offset: nil)
      @client.request(:get, "/comments#{query(compact(
        article_id: article_id, limit: limit, offset: offset
      ))}")
    end
  end

  # GET /follows — follower counts and the caller's follow state.
  class FollowsResource < Resource
    # @param user_id [String]
    def status(user_id:)
      @client.request(:get, "/follows#{query(compact(user_id: user_id))}")
    end
  end

  class Client
    attr_reader :ai, :articles, :images, :reactions, :series, :account, :analytics,
                :comments, :follows

    # @param api_key     [String] a `mbk_...` developer key or an OAuth 2.1 access token
    # @param base_url    [String] override the API base (default BASE_URL)
    # @param timeout     [Integer] per-request read timeout in seconds
    # @param max_retries [Integer] total attempts for retryable failures (>= 1)
    def initialize(api_key:, base_url: BASE_URL, timeout: 30, max_retries: 3)
      raise ArgumentError, "api_key is required" if api_key.nil? || api_key.empty?

      @api_key     = api_key
      @base_url    = base_url.chomp("/")
      @timeout     = timeout
      @max_retries = [max_retries, 1].max

      @ai        = AiResource.new(self)
      @articles  = ArticlesResource.new(self)
      @images    = ImagesResource.new(self)
      @reactions = ReactionsResource.new(self)
      @series    = SeriesResource.new(self)
      @account   = AccountResource.new(self)
      @analytics = AnalyticsResource.new(self)
      @comments  = CommentsResource.new(self)
      @follows   = FollowsResource.new(self)
    end

    # @param method [Symbol] :get, :post, :patch, :put, :delete
    # @param path   [String] e.g. "/articles"
    # @param data   [Hash]   request body (post/put/patch only)
    # @return [Hash]  decoded JSON body (empty Hash for 204/no-content)
    # @raise [ApiError, NetworkError]
    def request(method, path, data = {})
      url       = URI.parse(@base_url + "/" + path.delete_prefix("/"))
      has_body  = !data.empty? && %i[post put patch].include?(method)
      json_body = has_body ? JSON.generate(data) : nil

      last_status = 0

      @max_retries.times do |attempt|
        final = attempt == @max_retries - 1
        begin
          http              = Net::HTTP.new(url.host, url.port)
          http.use_ssl      = url.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = @timeout

          req  = build_request(method, url, json_body)
          resp = http.request(req)
          last_status = resp.code.to_i

          # Retry on transient statuses — but on the FINAL attempt, still
          # return/raise from the real response (never swallow the send).
          # A plan-limit 429 is not "slow down" — retrying cannot help until
          # the allowance resets or the plan changes, so fall straight through
          # to parse_response and raise instead of burning the retry budget.
          if RETRYABLE.include?(last_status) && !final && !plan_limit?(resp)
            sleep(RETRY_BASE_S * (2**attempt))
            next
          end

          return parse_response(resp, last_status)
        rescue Net::OpenTimeout, Net::ReadTimeout,
               Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
          raise NetworkError.new(e.message, e) if final

          sleep(RETRY_BASE_S * (2**attempt))
          next
        end
      end

      raise ApiError.new(last_status, "Max retries exceeded")
    end

    private

    def build_request(method, url, json_body)
      klass = case method
              when :get    then Net::HTTP::Get
              when :post   then Net::HTTP::Post
              when :patch  then Net::HTTP::Patch
              when :put    then Net::HTTP::Put
              when :delete then Net::HTTP::Delete
              else raise ArgumentError, "Unsupported HTTP method: #{method}"
              end

      req = klass.new(url.request_uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"]  = "application/json"
      req["Accept"]        = "application/json"
      req.body = json_body if json_body
      req
    end

    # True when the response body carries the API's plan-limit code.
    def plan_limit?(resp)
      body = resp.body
      return false if body.nil? || body.empty?

      decoded = JSON.parse(body)
      decoded.is_a?(Hash) && decoded["code"] == "plan_limit_exceeded"
    rescue JSON::ParserError
      false
    end

    def response_headers(resp)
      resp.each_header.to_h
    rescue StandardError
      {}
    end

    def parse_response(resp, status)
      return {} if status == 204 || resp.body.nil? || resp.body.empty?

      decoded = begin
        JSON.parse(resp.body)
      rescue JSON::ParserError
        nil
      end

      if status >= 400
        msg = decoded.is_a?(Hash) ? (decoded["error"] || decoded["message"] || resp.body) : resp.body
        if decoded.is_a?(Hash) && decoded["code"] == "plan_limit_exceeded"
          raise PlanLimitError.new(status, msg, decoded, response_headers(resp))
        end

        raise ApiError.new(status, msg, "api_error", decoded)
      end

      decoded.is_a?(Hash) ? decoded : { "data" => decoded }
    end
  end
end
