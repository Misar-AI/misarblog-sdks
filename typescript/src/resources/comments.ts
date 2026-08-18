import type { BlogApiClient } from "./client.js";

export interface CommentAuthor {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
}

export interface Comment {
  id: string;
  article_id: string;
  user_id: string;
  parent_id: string | null;
  content: string;
  is_edited: boolean;
  is_hidden: boolean;
  reply_count: number;
  created_at: string;
  updated_at: string;
  user: CommentAuthor;
  /** Nested one level deep; absent on reply objects themselves. */
  replies?: Comment[];
}

export interface CommentsResult {
  comments: Comment[];
  totalCount: number;
  hasMore: boolean;
}

export class CommentsResource {
  constructor(private readonly client: BlogApiClient) {}

  /**
   * GET /comments?article_id=&limit=&offset=
   *
   * An article's comment thread, newest first, with replies nested one level
   * deep. `limit` defaults to 20 (max 100) and `offset` to 0.
   *
   * Requires an API key like every other operation here — the request is
   * metered against the key's plan and rate-limited to 100 req/min.
   */
  list(
    articleId: string,
    options: { limit?: number; offset?: number } = {}
  ): Promise<CommentsResult> {
    const qs = new URLSearchParams({ article_id: articleId });
    if (options.limit !== undefined) qs.set("limit", String(options.limit));
    if (options.offset !== undefined) qs.set("offset", String(options.offset));
    return this.client.get<CommentsResult>(`/comments?${qs}`);
  }
}
