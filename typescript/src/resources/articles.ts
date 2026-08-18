import type { BlogApiClient } from "./client.js";

export type ArticleStatus =
  | "draft"
  | "published"
  | "scheduled"
  | "archived"
  | "flagged"
  | "all";

export type ArticleVisibility =
  | "public"
  | "subscribers"
  | "paid"
  | "private"
  | "webhook_only";

export interface ArticleSummary {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  status: string;
  tags: string[];
  published_at: string | null;
  created_at: string;
  view_count: number;
  is_premium: boolean;
  price_cents: number;
  url: string;
}

export interface Article extends ArticleSummary {
  content_markdown: string | null;
  content_html: string | null;
  visibility: string;
  updated_at: string | null;
  read_count: number;
  featured_image_url: string | null;
  editor_url: string;
}

export interface ArticleListResult {
  articles: ArticleSummary[];
  total: number;
}

export interface CreateArticleOptions {
  title: string;
  body_markdown: string;
  tags?: string[];
  cover_image_url?: string;
  schedule_at?: string;
  visibility?: ArticleVisibility;
}

export interface CreateDraftOptions {
  title: string;
  body_markdown: string;
  tags?: string[];
}

export interface UpdateArticleOptions {
  title?: string;
  body_markdown?: string;
  tags?: string[];
  /** Set true to publish a draft as part of the update. */
  publish?: boolean;
}

export interface SearchOptions {
  q?: string;
  type?: "all" | "articles" | "profiles" | "tags";
  tag?: string;
  author?: string;
  sort?: "relevance" | "newest" | "oldest" | "popular";
  from?: string;
  to?: string;
  limit?: number;
}

export class ArticlesResource {
  constructor(private readonly client: BlogApiClient) {}

  list(options: { status?: ArticleStatus; limit?: number } = {}): Promise<ArticleListResult> {
    const qs = new URLSearchParams();
    if (options.status && options.status !== "all") qs.set("status", options.status);
    if (options.limit) qs.set("limit", String(options.limit));
    const query = qs.toString() ? `?${qs}` : "";
    return this.client.get<ArticleListResult>(`/articles${query}`);
  }

  get(slug: string): Promise<Article> {
    return this.client.get<Article>(`/articles/${encodeURIComponent(slug)}`);
  }

  /**
   * PATCH /articles/{slug}
   *
   * Update an existing article. Omitted fields are left unchanged.
   */
  update(slug: string, options: UpdateArticleOptions): Promise<{
    id: string;
    slug: string;
    title: string;
    status: string;
    url: string;
    editor_url: string;
    published_at: string | null;
    updated_at: string | null;
  }> {
    return this.client.patch(`/articles/${encodeURIComponent(slug)}`, options);
  }

  create(options: CreateArticleOptions): Promise<{
    id: string;
    slug: string;
    title: string;
    status: string;
    url: string;
    editor_url: string;
    published_at: string | null;
    created_at: string;
  }> {
    return this.client.post(`/articles`, options);
  }

  createDraft(options: CreateDraftOptions): Promise<{
    id: string;
    slug: string;
    title: string;
    status: "draft";
    editor_url: string;
    created_at: string;
  }> {
    return this.client.post(`/drafts`, options);
  }

  search(options: SearchOptions = {}): Promise<{
    articles: unknown[];
    profiles: unknown[];
    tags: { name: string; count: number }[];
  }> {
    const qs = new URLSearchParams();
    if (options.q) qs.set("q", options.q);
    if (options.type) qs.set("type", options.type);
    if (options.tag) qs.set("tag", options.tag);
    if (options.author) qs.set("author", options.author);
    if (options.sort) qs.set("sort", options.sort);
    if (options.from) qs.set("from", options.from);
    if (options.to) qs.set("to", options.to);
    if (options.limit) qs.set("limit", String(options.limit));
    const query = qs.toString() ? `?${qs}` : "";
    return this.client.get(`/search${query}`);
  }

  recommendations(articleId: string, limit = 5): Promise<{ recommendations: unknown[] }> {
    return this.client.get(
      `/recommendations?article_id=${encodeURIComponent(articleId)}&limit=${limit}`
    );
  }
}
