/**
 * @misarblog/mcp
 *
 * TypeScript client for the Misar.Blog MCP server.
 * Use with Claude Desktop, Claude Code, Cursor, or any MCP-compatible AI client.
 *
 * MCP Endpoint: https://api.misar.io/blog/mcp
 * Auth: Bearer <mbk_YOUR_API_KEY>
 * Docs: https://docs.misar.io/blog/mcp
 */

/**
 * Default MCP endpoint for Misar.Blog.
 *
 * Override via {@link MisarBlogConfig.baseUrl} for a self-hosted deployment.
 */
export const MISARBLOG_MCP_URL = "https://api.misar.io/blog/mcp";

/** Options accepted by the {@link MisarBlogMCPClient} constructor. */
export interface MisarBlogConfig {
  /** Misar.Blog developer key — starts with mbk_. Generate at misar.blog/settings/api-keys. */
  apiKey: string;
  /** Base URL of the MCP server. Defaults to https://api.misar.io/blog/mcp */
  baseUrl?: string;
}

/** One tool the server exposes, from {@link MisarBlogMCPClient.listTools}. */
export interface MCPTool {
  /** Tool id to pass to {@link MisarBlogMCPClient.callTool}, e.g. `publish_article`. */
  name: string;
  /** What the tool does, when to use it, and what it changes. */
  description: string;
  /** JSON Schema for the tool's arguments. */
  inputSchema: Record<string, unknown>;
}

/**
 * The result of a tool call.
 *
 * A failing tool returns normally with `isError: true` rather than throwing —
 * check it before treating `content` as a success.
 */
/**
 * What the server reports when a session opens.
 *
 * Returned by {@link MisarBlogMCPClient.initialize}.
 */
export interface MCPInitializeResult {
  /** MCP protocol revision the server speaks, e.g. `2025-06-18`. */
  protocolVersion: string;
  /** Feature groups the server implements — tools, prompts, resources. */
  capabilities: Record<string, unknown>;
  /** The server's own name and version. */
  serverInfo: { name: string; version: string };
}

/** Shape of the client config block {@link getClaudeConfig} returns. */
export interface ClaudeConfig {
  /** Keyed by server id, as MCP clients expect in their config files. */
  mcpServers: Record<string, { url: string; headers: Record<string, string> }>;
}

export interface MCPCallResult {
  /** Result blocks, in order. Text blocks carry JSON for most tools. */
  content: Array<{ type: "text"; text: string }>;
  /** True when the tool itself failed; the reason is in `content`. */
  isError?: boolean;
}

/**
 * Misar.Blog MCP client for programmatic access to the MCP server.
 *
 * @example
 * ```typescript
 * import { MisarBlogMCPClient } from '@misarblog/mcp';
 *
 * const client = new MisarBlogMCPClient({ apiKey: 'mbk_your_key' });
 * await client.initialize();
 * const tools = await client.listTools();
 * const result = await client.callTool('publish_article', {
 *   title: 'Hello world',
 *   body_markdown: '# Hi',
 * });
 * ```
 */
export class MisarBlogMCPClient {
  private baseUrl: string;
  private headers: Record<string, string>;
  private sessionId: string | null = null;

  constructor(config: MisarBlogConfig) {
    this.baseUrl = config.baseUrl ?? MISARBLOG_MCP_URL;
    this.headers = {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.apiKey}`,
    };
  }

  private async jsonRpc(method: string, params?: Record<string, unknown>): Promise<unknown> {
    const body = {
      jsonrpc: "2.0",
      id: Date.now(),
      method,
      ...(params ? { params } : {}),
    };

    const reqHeaders: Record<string, string> = { ...this.headers };
    if (this.sessionId) {
      reqHeaders["Mcp-Session-Id"] = this.sessionId;
    }

    const res = await fetch(this.baseUrl, {
      method: "POST",
      headers: reqHeaders,
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${await res.text()}`);
    }

    const sessionId = res.headers.get("Mcp-Session-Id");
    if (sessionId) this.sessionId = sessionId;

    const data = (await res.json()) as {
      result?: unknown;
      error?: { code: number; message: string };
    };
    if (data.error) {
      throw new Error(`MCP error ${data.error.code}: ${data.error.message}`);
    }
    return data.result;
  }

  /** Initialize the MCP session and return server capabilities. */
  async initialize(): Promise<MCPInitializeResult> {
    return (await this.jsonRpc("initialize", {
      // Matches what the server negotiates; it was pinned a revision behind.
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "@misarblog/mcp-client", version: "1.1.0" },
    })) as MCPInitializeResult;
  }

  /** List all available MCP tools. */
  async listTools(): Promise<MCPTool[]> {
    const result = (await this.jsonRpc("tools/list")) as { tools: MCPTool[] };
    return result.tools;
  }

  /** Call a specific MCP tool by name. */
  async callTool(name: string, args: Record<string, unknown> = {}): Promise<MCPCallResult> {
    const result = await this.jsonRpc("tools/call", { name, arguments: args });
    return result as MCPCallResult;
  }

  // ─── Articles & Drafts ──────────────────────────────────────────────────────

  /** List the authenticated creator's articles. */
  async listMyArticles(params: { status?: string; limit?: number } = {}): Promise<MCPCallResult> {
    return this.callTool("list_my_articles", params);
  }

  /** Fetch a single article by slug or UUID. */
  async getArticle(params: { slug: string }): Promise<MCPCallResult> {
    return this.callTool("get_article", params);
  }

  /** Save an article as a draft. */
  async createDraft(params: { title: string; body_markdown: string; tags?: string[] }): Promise<MCPCallResult> {
    return this.callTool("create_draft", params);
  }

  /** Publish or schedule an article. */
  async publishArticle(params: {
    title: string;
    body_markdown: string;
    tags?: string[];
    cover_image_url?: string;
    schedule_at?: string;
    visibility?: string;
  }): Promise<MCPCallResult> {
    return this.callTool("publish_article", params);
  }

  // ─── Series ─────────────────────────────────────────────────────────────────

  /** List the authenticated creator's series. */
  async getSeries(): Promise<MCPCallResult> {
    return this.callTool("get_series");
  }

  /** Create a new series. */
  async createSeries(params: { title: string; description?: string }): Promise<MCPCallResult> {
    return this.callTool("create_series", params);
  }

  /** Add an article to a series. */
  async addToSeries(params: { series_slug: string; article_slug: string; position?: number }): Promise<MCPCallResult> {
    return this.callTool("add_to_series", params);
  }

  // ─── AI (titles, cover images, research) ────────────────────────────────────

  /** Generate article title suggestions from existing content. */
  async suggestTitles(params: { context?: string; prompt?: string }): Promise<MCPCallResult> {
    return this.callTool("suggest_titles", params);
  }

  /** Generate high-volume/low-competition SEO titles from a keyword prompt. */
  async generateTitleSeo(params: { prompt: string }): Promise<MCPCallResult> {
    return this.callTool("generate_title_seo", params);
  }

  /** Generate a cover image via AI and upload it to the CDN. */
  async generateCoverImage(params: { prompt: string; size?: string }): Promise<MCPCallResult> {
    return this.callTool("generate_cover_image", params);
  }

  /** Research a topic to gather source material for an article. */
  async researchTopic(params: { topic: string }): Promise<MCPCallResult> {
    return this.callTool("research_topic", params);
  }

  // ─── Reactions ──────────────────────────────────────────────────────────────

  /** Get reaction counts for an article plus the caller's own reactions. */
  async getReactions(params: { article_id: string }): Promise<MCPCallResult> {
    return this.callTool("get_reactions", params);
  }

  /** Add or toggle a reaction on an article. */
  async addReaction(params: { article_id: string; type: "like" | "clap" | "bookmark" }): Promise<MCPCallResult> {
    return this.callTool("add_reaction", params);
  }

  /** Remove a reaction from an article. */
  async removeReaction(params: { article_id: string; type: "like" | "clap" | "bookmark" }): Promise<MCPCallResult> {
    return this.callTool("remove_reaction", params);
  }

  // ─── Comments ───────────────────────────────────────────────────────────────

  /** List comments on an article. */
  async listComments(params: { article_id: string }): Promise<MCPCallResult> {
    return this.callTool("list_comments", params);
  }

  // ─── Newsletter ─────────────────────────────────────────────────────────────

  /** List newsletter issues. */
  async listNewsletterIssues(): Promise<MCPCallResult> {
    return this.callTool("list_newsletter_issues");
  }

  /** List newsletter subscribers. */
  async listNewsletterSubscribers(): Promise<MCPCallResult> {
    return this.callTool("list_newsletter_subscribers");
  }

  // ─── Profile & Analytics ────────────────────────────────────────────────────

  /** Get the authenticated creator's profile. */
  async getProfile(): Promise<MCPCallResult> {
    return this.callTool("get_profile");
  }

  /** Get the follow status between the caller and another profile. */
  async getFollowStatus(params: { username: string }): Promise<MCPCallResult> {
    return this.callTool("get_follow_status", params);
  }

  /** Get an analytics summary for the caller. */
  async getAnalyticsSummary(params: { days?: number } = {}): Promise<MCPCallResult> {
    return this.callTool("get_analytics_summary", params);
  }
}

/**
 * Returns the Claude Desktop / Claude Code MCP configuration JSON for Misar.Blog.
 *
 * @example
 * ```typescript
 * import { getClaudeConfig } from '@misarblog/mcp';
 * console.log(JSON.stringify(getClaudeConfig('mbk_your_key'), null, 2));
 * ```
 */
export function getClaudeConfig(apiKey: string): ClaudeConfig {
  return {
    mcpServers: {
      misarblog: {
        url: MISARBLOG_MCP_URL,
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
      },
    },
  };
}

/** The client class, also available as a default import. */
export default MisarBlogMCPClient;
