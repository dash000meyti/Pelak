#!/usr/bin/env sh

set -euo pipefail

CACHE_DIR="./registry/packages"
TMP_LOCK="./registry/.tmp-lock.json"

mkdir -p "$CACHE_DIR"

echo "🌍 Pulling ALL platforms (clean + dedup)..."
echo "📦 Cache: $CACHE_DIR"
echo ""

PLATFORMS="linux darwin win32"
ARCHS="x64 arm64"

# پاک کردن لاک موقت
rm -f "$TMP_LOCK"

for platform in $PLATFORMS; do
  for arch in $ARCHS; do

    echo "==============================="
    echo "📦 $platform / $arch"
    echo "==============================="

    npm_config_platform=$platform \
    npm_config_arch=$arch \
    npm_config_optional=true \
    npm install \
      --package-lock-only \
      --ignore-scripts \
      --no-audit \
      --no-fund \
      >/dev/null 2>&1 || true

    # merge lock ها
    if [ -f package-lock.json ]; then
      jq -s '
        reduce .[] as $item ({}; . * $item)
      ' "$TMP_LOCK" package-lock.json 2>/dev/null > "$TMP_LOCK.tmp" || cp package-lock.json "$TMP_LOCK.tmp"

      mv "$TMP_LOCK.tmp" "$TMP_LOCK"
    fi

  done
done

echo ""
echo "🔍 Extracting tarballs (deduplicated)..."

jq -r '
  .packages
  | to_entries[]
  | select(.value.resolved)
  | .value.resolved
' "$TMP_LOCK" \
| sort -u \
| while read -r url; do

  file="$CACHE_DIR/$(basename "$url")"

  if [ -f "$file" ]; then
    echo "🔻 Cached: $(basename "$file")"
    continue
  fi

  echo "🔽 Downloading: $(basename "$file")"

  if ! curl -fL "$url" -o "$file"; then
    echo "❌ Failed: $url"
    rm -f "$file"
  fi

done

echo ""
echo "🧹 Cleanup..."
rm -f "$TMP_LOCK"

echo "✅ Pull complete"