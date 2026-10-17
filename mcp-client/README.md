# ⚠️ Do not publish this directory

This is a **stale local copy** of the Misar.Blog MCP client. It is marked
`private: true` and renamed `@misarblog/mcp-client-legacy` so that no publish
pipeline can pick it up.

## Why

The name it used to claim — `@misarblog/mcp` — is **live on npm at 2.0.0**,
released from a different repository:

| | This directory | The real package |
| --- | --- | --- |
| Name | `@misarblog/mcp-client-legacy` | `@misarblog/mcp` |
| Version | 1.1.0 (stale) | 2.0.0 |
| Source | `sdks/mcp-client` | [`Misar-AI/misarblog-mcp`](https://github.com/Misar-AI/misarblog-mcp) |
| Exports | `.` only | `.`, `./http`, `./server` |
| Binary | none | `misarblog-mcp` |

This app depends on `@misarblog/mcp@^2.0.0` and imports both extra subpaths in
[`src/app/api/mcp/route.ts`](../../src/app/api/mcp/route.ts):

```ts
import { createBlogHttpHandler, corsPreflight } from "@misarblog/mcp/http";
import { buildServer, describeServer, SERVER_NAME, SERVER_VERSION } from "@misarblog/mcp/server";
```

Publishing this directory under the old name would have shipped a **1.1.0 that
drops `./http` and `./server`**, breaking the MCP route for every fresh install.

## What to do instead

- **Consuming the MCP server** — `npm install @misarblog/mcp`, or point your
  client at the hosted endpoint `https://api.misar.io/blog/mcp` with an
  `mbk_` key as a Bearer token.
- **Changing the MCP server** — do it in
  [`Misar-AI/misarblog-mcp`](https://github.com/Misar-AI/misarblog-mcp)
  and release from there. The registry listing in
  [`server.json`](../../server.json) points at that package.
- **Retiring this directory** — once you have confirmed nothing depends on it,
  delete it. It is kept only so the divergence is visible rather than silent.

## Registry listing

The MCP Registry entry is published from the repo root by
`.forgejo/workflows/publish-mcp-registry.yml`, reading
[`server.json`](../../server.json). It describes the hosted remote endpoint and
the real npm package — never this directory.
