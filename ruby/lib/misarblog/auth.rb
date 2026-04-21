require "net/http"
require "uri"
require "json"

module MisarBlog
  def self.refresh_token(token:, base_url: "https://misar.blog")
    uri = URI.parse("#{base_url}/api/auth/refresh")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = JSON.generate({ token: token })
    response = http.request(request)
    raise "HTTP error: #{response.code}" unless response.code.to_i == 200
    JSON.parse(response.body, symbolize_names: true)
  end
end
