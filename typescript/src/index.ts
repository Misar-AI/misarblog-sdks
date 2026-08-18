/**
 * Official TypeScript/JavaScript SDK for the Misar.Blog developer API.
 *
 * Every API call goes through the metered gateway at
 * `https://api.misar.io/blog/v1` with an `mbk_` developer key as a Bearer
 * token; feature access and throughput follow the subscription attached to
 * that key. A blocked call throws {@link PlanLimitError}, which carries the
 * upgrade URL to surface to the user.
 *
 * API keys are minted in the dashboard at
 * https://www.misar.blog/dashboard/settings/api — key management is a
 * cookie-session flow and is deliberately not exposed here.
 */

// Public embed URLs (no API key, no metering — these are public pages).
export { embed, embedUrl } from "./embed.js";
export type { EmbedOptions, EmbedResult } from "./embed.js";

// API client
export { MisarBlog } from "./blog.js";
export type { MisarBlogOptions } from "./blog.js";

// Resources, errors and models
export {
  BlogApiClient,
  BlogApiError,
  PlanLimitError,
  NetworkError,
  AiResource,
  ArticlesResource,
  ProfilesResource,
  AnalyticsResource,
  CommentsResource,
  FollowsResource,
  ReactionsResource,
  SeriesResource,
  ImagesResource,
  PlanResource,
  UpsellResource,
} from "./resources/index.js";

export type {
  BlogApiClientOptions,
  TitleResult,
  TitlesResponse,
  GenerateTitlesOptions,
  CompleteOptions,
  CompletionResponse,
  ArticleSummary,
  Article,
  ArticleListResult,
  CreateArticleOptions,
  CreateDraftOptions,
  UpdateArticleOptions,
  SearchOptions,
  ArticleStatus,
  ArticleVisibility,
  Profile,
  AnalyticsSummary,
  Comment,
  CommentsResult,
  FollowStatus,
  ArticleReactionsResult,
  Series,
  CreateSeriesOptions,
  ImageSize,
  GeneratedImage,
  UploadedImage,
  Plan,
  PlanUsage,
  TrialStatus,
  StartTrialOptions,
} from "./resources/index.js";
