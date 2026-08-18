require "misarblog/embed"
require "misarblog/errors"
require "misarblog/models"
require "misarblog/client"

module MisarBlog
  # Convenience constructor: MisarBlog.new(api_key: "mbk_...")
  def self.new(**kwargs)
    Client.new(**kwargs)
  end
end
