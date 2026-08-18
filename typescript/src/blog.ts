import { BlogApiClient, type BlogApiClientOptions } from "./resources/client.js";
import { AiResource } from "./resources/ai.js";
import { ArticlesResource } from "./resources/articles.js";
import { ProfilesResource } from "./resources/profiles.js";
import { AnalyticsResource } from "./resources/analytics.js";
import { CommentsResource } from "./resources/comments.js";
import { FollowsResource } from "./resources/follows.js";
import { ReactionsResource } from "./resources/reactions.js";
import { SeriesResource } from "./resources/series.js";
import { ImagesResource } from "./resources/images.js";
import { PlanResource, UpsellResource } from "./resources/plan.js";

export interface MisarBlogOptions extends BlogApiClientOptions {
  /** Developer key (`mbk_...`) or an OAuth 2.1 access token. */
  apiKey: string;
}

/**
 * Client for the Misar.Blog developer API — all 25 key-authenticated
 * operations, grouped into resource accessors.
 *
 * Every call goes through the metered `/blog/v1` gateway with the API key as a
 * Bearer token; feature access and throughput follow the subscription attached
 * to that key. A blocked call throws `PlanLimitError`, which carries the
 * upgrade URL.
 *
 * @example
 * const blog = new MisarBlog({ apiKey: "mbk_..." });
 * const me = await blog.profiles.me();
 * await blog.articles.create({ title: "Hello", body_markdown: "# Hi" });
 */
export class MisarBlog {
  readonly ai: AiResource;
  readonly articles: ArticlesResource;
  readonly profiles: ProfilesResource;
  readonly analytics: AnalyticsResource;
  readonly comments: CommentsResource;
  readonly follows: FollowsResource;
  readonly reactions: ReactionsResource;
  readonly series: SeriesResource;
  readonly images: ImagesResource;
  readonly plan: PlanResource;
  readonly upsell: UpsellResource;

  constructor(options: MisarBlogOptions) {
    const { apiKey, ...clientOptions } = options;
    const client = new BlogApiClient(apiKey, clientOptions);

    this.ai = new AiResource(client);
    this.articles = new ArticlesResource(client);
    this.profiles = new ProfilesResource(client);
    this.analytics = new AnalyticsResource(client);
    this.comments = new CommentsResource(client);
    this.follows = new FollowsResource(client);
    this.reactions = new ReactionsResource(client);
    this.series = new SeriesResource(client);
    this.images = new ImagesResource(client);
    this.plan = new PlanResource(client);
    this.upsell = new UpsellResource(client);
  }
}
