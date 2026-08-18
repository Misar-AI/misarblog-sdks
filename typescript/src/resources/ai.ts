import type { BlogApiClient } from "./client.js";

export interface TitleResult {
  title: string;
  hint: string;
}

export interface TitlesResponse {
  titles: TitleResult[];
  raw: string;
}

export interface GenerateTitlesOptions {
  /**
   * "suggest" — generate titles from existing article content.
   * "seo"     — generate high-volume/low-competition titles from a keyword prompt.
   */
  action: "suggest" | "seo";
  /** Required when action="seo". Target keyword or topic. Max 500 chars. */
  prompt?: string;
  /** Optional article content for context. Max 8000 chars. Required when action="suggest". */
  context?: string;
}

export interface CompleteOptions {
  /** The user prompt. */
  prompt: string;
  /** Optional system instruction. */
  system?: string;
  /** Upper bound on generated tokens. */
  max_tokens?: number;
}

export interface CompletionResponse {
  text: string;
  [key: string]: unknown;
}

export class AiResource {
  constructor(private readonly client: BlogApiClient) {}

  /**
   * POST /ai/titles
   *
   * Generate SEO/AEO/GEO article title suggestions.
   * Requires API key authentication.
   *
   * @example
   * const { titles } = await blog.ai.titles({
   *   action: "seo",
   *   prompt: "best AI writing tools for beginner bloggers 2025",
   * });
   */
  titles(options: GenerateTitlesOptions): Promise<TitlesResponse> {
    return this.client.post<TitlesResponse>("/ai/titles", options);
  }

  /**
   * POST /ai/complete
   *
   * Generic system + user prompt completion. Spends AI credits, so a plan
   * without an allowance rejects the call with a {@link PlanLimitError}.
   */
  complete(options: CompleteOptions): Promise<CompletionResponse> {
    return this.client.post<CompletionResponse>("/ai/complete", options);
  }
}
