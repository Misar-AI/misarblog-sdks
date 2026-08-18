import type { BlogApiClient } from "./client.js";

export interface Series {
  id: string;
  slug: string;
  title: string;
  description: string | null;
  cover_image_url: string | null;
  visibility: string;
  created_at: string;
  url: string;
}

export interface CreateSeriesOptions {
  title: string;
  description?: string;
}

export class SeriesResource {
  constructor(private readonly client: BlogApiClient) {}

  list(): Promise<{ series: Series[] }> {
    return this.client.get<{ series: Series[] }>("/series");
  }

  /**
   * POST /series/{slug}/articles
   *
   * Add an article to a series. `position` appends when omitted.
   *
   * Note: there is no GET on this path — the API exposes series contents
   * through `list()` only. A previous release issued a GET here and always
   * received 405.
   */
  addArticle(
    slug: string,
    articleSlug: string,
    position?: number
  ): Promise<Record<string, unknown>> {
    return this.client.post(`/series/${encodeURIComponent(slug)}/articles`, {
      article_slug: articleSlug,
      ...(position !== undefined ? { position } : {}),
    });
  }

  create(options: CreateSeriesOptions): Promise<{
    id: string;
    slug: string;
    title: string;
    url: string;
    created_at: string;
  }> {
    return this.client.post("/series", options);
  }
}
