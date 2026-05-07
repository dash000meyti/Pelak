#!/usr/bin/env sh

set -euo pipefail

BASE_DIR="./registry/packages"
TODO_DIR="$BASE_DIR/todo"
DONE_DIR="$BASE_DIR/done"
TMP_LOCK="./registry/.tmp-lock.json"

mkdir -p "$TODO_DIR" "$DONE_DIR"

echo "🌍 Pulling ALL platforms (clean + dedup)..."
echo "📦 Todo:  $TODO_DIR"
echo "📁 Done:  $DONE_DIR"
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

  base="$(basename "$url")"
  todo_file="$TODO_DIR/$base"
  done_file="$DONE_DIR/$base"

  if [ -f "$todo_file" ] || [ -f "$done_file" ]; then
    echo "🔻 Already tracked: $base"
    continue
  fi

  echo "🔽 Downloading: $base"

  if ! curl -fL "$url" -o "$todo_file"; then
    echo "❌ Failed: $url"
    rm -f "$todo_file"
  fi

done

echo ""
echo "🧹 Cleanup..."
rm -f "$TMP_LOCK"

echo "✅ Pull complete"