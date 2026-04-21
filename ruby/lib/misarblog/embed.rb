module MisarBlog
  EMBED_BASE = "https://misar.blog".freeze

  def self.embed_url(username:, slug: nil, theme: "auto")
    url = "#{EMBED_BASE}/#{username}"
    url = "#{url}/#{slug}" if slug && !slug.empty?
    url = "#{url}/embed"
    url = "#{url}?theme=#{theme}" if theme != "auto"
    url
  end
end
