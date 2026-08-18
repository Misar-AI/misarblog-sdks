export {
  BlogApiClient,
  BlogApiError,
  PlanLimitError,
  NetworkError,
} from "./client.js";
export type { BlogApiClientOptions } from "./client.js";

export { AiResource } from "./ai.js";
export type {
  TitleResult,
  TitlesResponse,
  GenerateTitlesOptions,
  CompleteOptions,
  CompletionResponse,
} from "./ai.js";

export { ArticlesResource } from "./articles.js";
export type {
  ArticleSummary,
  Article,
  ArticleListResult,
  CreateArticleOptions,
  CreateDraftOptions,
  UpdateArticleOptions,
  SearchOptions,
  ArticleStatus,
  ArticleVisibility,
} from "./articles.js";

export { ProfilesResource } from "./profiles.js";
export type { Profile } from "./profiles.js";

export { AnalyticsResource } from "./analytics.js";
export type { AnalyticsSummary } from "./analytics.js";

export { CommentsResource } from "./comments.js";
export type { Comment, CommentAuthor, CommentsResult } from "./comments.js";

export { FollowsResource } from "./follows.js";
export type { FollowStatus } from "./follows.js";

export { ReactionsResource } from "./reactions.js";
export type { ArticleReactionsResult } from "./reactions.js";

export { SeriesResource } from "./series.js";
export type { Series, CreateSeriesOptions } from "./series.js";

export { ImagesResource } from "./images.js";
export type { ImageSize, GeneratedImage, UploadedImage } from "./images.js";

export { PlanResource, UpsellResource } from "./plan.js";
export type { Plan, PlanUsage, TrialStatus, StartTrialOptions } from "./plan.js";
