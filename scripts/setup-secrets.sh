#!/usr/bin/env bash
# Configure GitHub Actions secrets for SDK auto-publishing.
# Run once after creating accounts on each registry.
#
# Usage:  bash scripts/setup-secrets.sh
#         REPO=Misar-AI/misarblog-sdks bash scripts/setup-secrets.sh

set -e
REPO="${REPO:-Misar-AI/misarblog-sdks}"
echo "Configuring secrets for: $REPO"

set_secret() {
  local name="$1" value="$2"
  [ -z "$value" ] || [ "$value" = "skip" ] && { echo "  ↷ $name skipped"; return; }
  printf "%s" "$value" | gh secret set "$name" -R "$REPO" && echo "  ✓ $name"
}

prompt() {
  local label="$1" hint="$2"
  echo; echo "── $label"; echo "  $hint"
  printf "  Value (enter to skip): "; read -r val; echo "$val"
}

# npm — TypeScript, CLI, Solidity
set_secret "NPM_TOKEN" "$(prompt NPM_TOKEN \
  'npmjs.com → Account → Access Tokens → Granular → publish scope')"

# PyPI — Python (OIDC, no token)
echo; echo "── PyPI OIDC (no token needed)"
echo "  pypi.org → Account → Publishing → Add trusted publisher:"
echo "    Owner: Misar-AI | Repo: ${REPO##*/} | Workflow: publish-python.yml"
printf "  Press enter when configured (or skip): "; read -r _

# crates.io — Rust
set_secret "CARGO_REGISTRY_TOKEN" "$(prompt CARGO_REGISTRY_TOKEN \
  'crates.io → Account Settings → API Tokens → New Token (publish-new, publish-update)')"

# RubyGems — Ruby
set_secret "RUBYGEMS_API_KEY" "$(prompt RUBYGEMS_API_KEY \
  'rubygems.org → Profile → API Keys → New Key → Push gems scope')"

# NuGet — C#
set_secret "NUGET_API_KEY" "$(prompt NUGET_API_KEY \
  'nuget.org → API Keys → Create → Push scope')"

# Maven Central — Java, Kotlin
echo; echo "── Maven Central (OSSRH) — Java & Kotlin"
echo "  central.sonatype.com → Account → Security → Generate User Token"
set_secret "OSSRH_USERNAME" "$(prompt OSSRH_USERNAME 'Sonatype token username')"
set_secret "OSSRH_TOKEN"    "$(prompt OSSRH_TOKEN    'Sonatype token password')"

# Packagist — PHP
set_secret "PACKAGIST_API_TOKEN" "$(prompt PACKAGIST_API_TOKEN \
  'packagist.org → Profile → Show API Token  |  Also submit repo URL at packagist.org/packages/submit')"

# pub.dev — Dart, Flutter
echo; echo "── pub.dev credentials (Dart & Flutter)"
echo "  Run:  dart pub login"
echo "  Then: cat ~/.config/dart/pub-credentials.json"
echo "  Paste full JSON (blank line to end):"
PUB_CREDS=""; while IFS= read -r line; do [ -z "$line" ] && break; PUB_CREDS+="$line"$'\n'; done
set_secret "PUB_CREDENTIALS" "${PUB_CREDS%$'\n'}"

# Swift Package Index — optional
set_secret "SPI_TOKEN" "$(prompt SPI_TOKEN \
  'Optional — swiftpackageindex.com → Dashboard → API Token')"

echo
echo "All done. Verify: https://github.com/$REPO/settings/secrets/actions"
echo "GPG secrets already set (Key: 4EB8EC97E650EBF8 / sdk@misar.io, expires 2029-04-20)"
