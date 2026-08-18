import type { BlogApiClient } from "./client.js";

export type ReactionType = "like" | "clap" | "bookmark";

export interface ArticleReactionsResult {
  article_id: string;
  counts: Record<ReactionType, number>;
  total: number;
  user_reactions: ReactionType[];
}

export interface ReactionMutationResult {
  success: boolean;
  reacted: boolean;
  toggled?: boolean;
}

export class ReactionsResource {
  constructor(private readonly client: BlogApiClient) {}

  /**
   * GET /reactions?article_id=xxx
   *
   * Returns reaction counts and the authenticated user's reactions for an article.
   * Requires a valid API key.
   */
  get(articleId: string): Promise<ArticleReactionsResult> {
    return this.client.get<ArticleReactionsResult>(
      `/reactions?article_id=${encodeURIComponent(articleId)}`
    );
  }

  /**
   * POST /reactions
   *
   * Add a reaction to an article. No-ops if already reacted (idempotent).
   * @param articleId - UUID of the article
   * @param type - Reaction type: "like" | "clap" | "bookmark"
   */
  add(articleId: string, type: ReactionType): Promise<ReactionMutationResult> {
    return this.client.post<ReactionMutationResult>("/reactions", {
      article_id: articleId,
      type,
    });
  }

  /**
   * DELETE /reactions?article_id=xxx&type=xxx
   *
   * Remove a specific reaction from an article.
   * @param articleId - UUID of the article
   * @param type - Reaction type: "like" | "clap" | "bookmark"
   */
  remove(articleId: string, type: ReactionType): Promise<ReactionMutationResult> {
    return this.client.delete<ReactionMutationResult>(
      `/reactions?article_id=${encodeURIComponent(articleId)}&type=${encodeURIComponent(type)}`
    );
  }
}
