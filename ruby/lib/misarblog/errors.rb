module MisarBlog
  # Raised when the Misar.Blog dev-API returns a non-2xx response.
  class ApiError < StandardError
    attr_reader :status, :error_type, :body

    def initialize(status, message, error_type = "api_error", body = nil)
      @status = status
      @error_type = error_type
      @body = body
      super("misar-blog: API error #{status} (#{error_type}): #{message}")
    end
  end

  # Raised when the subscription attached to the API key blocks the call.
  #
  # The API signals this with `code: "plan_limit_exceeded"` and answers 429 when
  # a metered allowance is exhausted (retryable once the period rolls over) or
  # 402 when the feature is locked outright. It is raised as its own class
  # rather than a generic 429 because retrying cannot help until the allowance
  # resets or the plan changes — the client stops retrying on sight.
  class PlanLimitError < ApiError
    # @return [String, nil] the account's current plan slug
    attr_reader :plan
    # @return [String, nil] pricing page to send the user to
    attr_reader :upgrade_url
    # @return [Integer, nil] seconds until the allowance resets
    attr_reader :retry_after
    # @return [Hash] the full upgrade offer from the response body
    attr_reader :upgrade

    def initialize(status, message, body = nil, headers = {})
      body    ||= {}
      headers   = (headers || {}).transform_keys { |k| k.to_s.downcase }
      @upgrade  = body["upgrade"].is_a?(Hash) ? body["upgrade"] : {}
      @plan     = headers["x-misar-plan"] || @upgrade.dig("current_plan", "slug")
      # Headers are authoritative; fall back to the offer body when a proxy has
      # stripped them.
      @upgrade_url = headers["x-misar-upgrade-url"] || @upgrade.dig("urls", "pricing")
      ra           = headers["retry-after"]
      @retry_after = ra&.match?(/\A\d+\z/) ? ra.to_i : nil
      super(status, message, "plan_limit_exceeded", body)
    end
  end

  # Raised for connectivity failures where no HTTP response was received.
  class NetworkError < ApiError
    attr_reader :cause_error

    def initialize(message, cause = nil)
      super(0, message, "network_error")
      @cause_error = cause
    end
  end
end
