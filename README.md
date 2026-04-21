# Misar.Blog SDKs

Official client SDKs for [Misar.Blog](https://misar.blog) — embed article/profile widgets and handle auth token refresh.

## Packages

| Language | Package | Registry |
|----------|---------|----------|
| TypeScript / JavaScript | `@misar/blog` | [npm](https://www.npmjs.com/package/@misar/blog) |
| CLI | `@misarblog/cli` | [npm](https://www.npmjs.com/package/@misarblog/cli) |
| Python | `misarblog-sdk` | [PyPI](https://pypi.org/project/misarblog-sdk/) |
| Go | `github.com/misar-ai/misarblog-go` | [pkg.go.dev](https://pkg.go.dev/github.com/Misar-AI/misarblog-sdks/go) |
| Ruby | `misarblog` | [RubyGems](https://rubygems.org/gems/misarblog) |
| PHP | `misarblog/sdk` | [Packagist](https://packagist.org/packages/misarblog/sdk) |
| Java | `blog.misar:misarblog-sdk` | [Maven Central](https://central.sonatype.com/) |
| Kotlin | `blog.misar:misarblog-sdk-kotlin` | [Maven Central](https://central.sonatype.com/) |
| C# | `MisarBlog.SDK` | [NuGet](https://www.nuget.org/packages/MisarBlog.SDK) |
| Rust | `misarblog-sdk` | [crates.io](https://crates.io/crates/misarblog-sdk) |
| Swift | `MisarBlog` | [Swift Package Index](https://swiftpackageindex.com/) |
| Dart | `misarblog_sdk` | [pub.dev](https://pub.dev/packages/misarblog_sdk) |
| Flutter | `misarblog_flutter` | [pub.dev](https://pub.dev/packages/misarblog_flutter) |
| C | `libmisarblog` | [GitHub Releases](https://github.com/Misar-AI/misarblog-sdks/releases) |
| C++ | `libmisarblog_cpp` | [GitHub Releases](https://github.com/Misar-AI/misarblog-sdks/releases) |
| Solidity | `@misarblog/contracts` | [npm](https://www.npmjs.com/package/@misarblog/contracts) |

## Core API

Every SDK exposes the same two primitives:

**`embedUrl(username, slug?, theme?)`** — returns the embed URL for an article or profile widget.

**`refreshToken(token, baseUrl?)`** — exchanges a token via `POST /api/auth/refresh` and returns `{ token, expiresAt }`.

## Publishing

Releases are triggered by git tags using the pattern `<lang>/v<semver>`:

```bash
git tag typescript/v1.0.0 && git push origin typescript/v1.0.0
git tag python/v1.0.0    && git push origin python/v1.0.0
# etc.
```

## Required Secrets

Set these in the GitHub repo **Settings → Secrets and variables → Actions**:

| Secret | Used by |
|--------|---------|
| `NPM_TOKEN` | typescript, cli, solidity |
| `PYPI_API_TOKEN` | python (fallback; OIDC preferred) |
| `RUBYGEMS_API_KEY` | ruby |
| `PACKAGIST_API_TOKEN` | php |
| `OSSRH_USERNAME` | java, kotlin |
| `OSSRH_TOKEN` | java, kotlin |
| `GPG_PRIVATE_KEY` | java, kotlin |
| `GPG_KEY_ID` | kotlin |
| `GPG_PASSPHRASE` | java, kotlin |
| `NUGET_API_KEY` | csharp |
| `CARGO_REGISTRY_TOKEN` | rust |
| `PUB_CREDENTIALS` | dart, flutter |
