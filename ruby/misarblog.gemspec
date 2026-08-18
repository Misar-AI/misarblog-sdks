Gem::Specification.new do |spec|
  spec.name          = "misarblog"
  spec.version       = "5.0.3"
  spec.authors       = ["Misar AI"]
  spec.email         = ["hello@misar.io"]
  spec.summary       = "Ruby client for misar.blog, a hosted blogging platform: publish and " \
                       "schedule Markdown articles, manage drafts and series, read comments, " \
                       "reactions, follows and analytics, and generate AI titles and covers."
  spec.description   = "Ruby client for the developer API of Misar.Blog (misar.blog), a hosted " \
                       "blogging platform. Publish or schedule Markdown articles, save and update " \
                       "drafts, group articles into series, read comment threads, reactions and " \
                       "follows, pull an analytics summary and live plan/quota state, generate " \
                       "SEO/AEO/GEO title suggestions, completions and AI cover images, search " \
                       "articles, profiles and tags, and build public iframe embed URLs — all 25 " \
                       "key-authenticated operations. Standard library only (net/http): mbk_ bearer " \
                       "auth, retry with exponential back-off, and a typed PlanLimitError carrying " \
                       "the upgrade URL."
  spec.homepage      = "https://www.misar.blog"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "source_code_uri"   => "https://github.com/Misar-AI/misarblog-sdks",
    "changelog_uri"     => "https://github.com/Misar-AI/misarblog-sdks/releases",
    "documentation_uri" => "https://docs.misar.io/blog",
    "bug_tracker_uri"   => "https://github.com/Misar-AI/misarblog-sdks/issues"
  }

  spec.files         = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  # Uses only the Ruby standard library (net/http, uri, json) at runtime.
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
end
