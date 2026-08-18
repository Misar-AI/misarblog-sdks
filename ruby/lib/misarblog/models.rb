module MisarBlog
  # Typed models for the Misar.Blog dev-API. Each wraps the decoded JSON body
  # and exposes the documented fields, while `#raw` keeps the original Hash for
  # forward-compatibility with fields added after this SDK was published.
  module Models
    # Base class: stores the raw Hash and offers indifferent-ish access.
    class Base
      attr_reader :raw

      def initialize(raw)
        @raw = raw || {}
      end

      def [](key)
        @raw[key.to_s]
      end

      def to_h
        @raw
      end
    end

    # An article (draft, scheduled, published, ...).
    class Article < Base
      def id;           @raw["id"];            end
      def slug;         @raw["slug"];          end
      def title;        @raw["title"];         end
      def status;       @raw["status"];        end
      def url;          @raw["url"];           end
      def editor_url;   @raw["editor_url"];    end
      def excerpt;      @raw["excerpt"];       end
      def tags;         @raw["tags"] || [];    end
      def visibility;   @raw["visibility"];    end
      def published_at; @raw["published_at"];  end
      def created_at;   @raw["created_at"];    end
    end

    # Result of GET /articles.
    class ArticleList < Base
      def articles; (@raw["articles"] || []).map { |a| Article.new(a) }; end
      def total;    @raw["total"];                                       end
    end

    # A series/collection of articles.
    class Series < Base
      def id;            @raw["id"];            end
      def slug;          @raw["slug"];          end
      def title;         @raw["title"];         end
      def description;   @raw["description"];   end
      def article_count; @raw["article_count"]; end
      def created_at;    @raw["created_at"];    end
    end

    # Result of GET /series.
    class SeriesList < Base
      def series; (@raw["series"] || []).map { |s| Series.new(s) }; end
    end

    # The authenticated developer's public profile (GET /me).
    class Profile < Base
      def id;               @raw["id"];               end
      def username;         @raw["username"];         end
      def display_name;     @raw["display_name"];     end
      def bio;              @raw["bio"];              end
      def avatar_url;       @raw["avatar_url"];       end
      def stripe_connected; @raw["stripe_connected"]; end
      def profile_url;      @raw["profile_url"];      end
      def created_at;       @raw["created_at"];       end
    end

    # A single plan-usage counter row.
    class PlanUsage < Base
      def feature;       @raw["feature"];       end
      def feature_label; @raw["feature_label"]; end
      def used;          @raw["used"];          end
      def limit;         @raw["limit"];         end
      def remaining;     @raw["remaining"];     end
      def period;        @raw["period"];        end
      def resets_at;     @raw["resets_at"];     end
    end

    # Plan + usage snapshot (GET /plan).
    class Plan < Base
      def plan;    @raw["plan"];                                          end
      def slug;    (@raw["plan"] || {})["slug"];                          end
      def name;    (@raw["plan"] || {})["name"];                          end
      def usage;   (@raw["usage"] || []).map { |u| PlanUsage.new(u) };    end
      def upgrade; @raw["upgrade"];                                       end
    end

    # Account-wide analytics summary (GET /analytics).
    class Analytics < Base
      def period_days;       @raw["period_days"];       end
      def views;             @raw["views"];             end
      def revenue_cents;     @raw["revenue_cents"];     end
      def revenue_net_cents; @raw["revenue_net_cents"]; end
      def active_subscribers; @raw["active_subscribers"]; end
    end

    # Reaction counts for an article (GET /reactions).
    class ArticleReactions < Base
      def article_id;     @raw["article_id"];              end
      def counts;         @raw["counts"] || {};            end
      def total;          @raw["total"];                   end
      def user_reactions; @raw["user_reactions"] || [];    end
    end

    # Result of adding/removing a reaction.
    class ReactionResult < Base
      def success; @raw["success"]; end
      def reacted; @raw["reacted"]; end
    end

    # Trial eligibility/status (GET /trial).
    class TrialStatus < Base
      def eligible;      @raw["eligible"];      end
      def active;        @raw["active"];        end
      def ends_at;       @raw["ends_at"];       end
      def plan_slug;     @raw["plan_slug"];     end
      def days;          @raw["days"];          end
      def requires_card; @raw["requires_card"]; end
      def reason;        @raw["reason"];        end
    end

    # A single generated title suggestion.
    class TitleSuggestion < Base
      def title; @raw["title"]; end
      def hint;  @raw["hint"];  end
    end

    # Result of POST /ai/titles.
    class TitlesResult < Base
      def titles; (@raw["titles"] || []).map { |t| TitleSuggestion.new(t) }; end
    end

    # Result of POST /ai/complete.
    class AiText < Base
      def text; @raw["text"]; end
    end

    # Result of the image endpoints.
    class ImageResult < Base
      def url; @raw["url"]; end
    end
  end
end
