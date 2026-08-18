Gem::Specification.new do |spec|
  spec.name          = "misarblog"
  spec.version       = "1.1.0"
  spec.authors       = ["Misar AI"]
  spec.email         = ["hello@misar.io"]
  spec.summary       = "Official Ruby SDK for Misar.Blog — articles, series, reactions, AI, analytics"
  spec.description   = "Full-featured Ruby SDK for the Misar.Blog developer API " \
                       "(api.misar.io/blog/v1). Covers all 25 dev-API operations with " \
                       "typed models, mbk_ bearer auth, and retry with exponential backoff."
  spec.homepage      = "https://www.misar.blog/docs/sdks/ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://github.com/Misar-AI/misarblog-sdks",
    "changelog_uri"   => "https://github.com/Misar-AI/misarblog-sdks/releases"
  }

  spec.files         = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  # Uses only the Ruby standard library (net/http, uri, json) at runtime.
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
end
