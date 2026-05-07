#!/bin/sh

set -eu

REGISTRY="http://localhost:4873"

export NPM_CONFIG_PROVENANCE=false

CACHE_DIR="./registry/packages"
DONE_DIR="$CACHE_DIR/done"

mkdir -p "$DONE_DIR"

echo "🚀 Pushing to Verdaccio..."
echo "🌐 Registry: $REGISTRY"
echo "📦 Source: $CACHE_DIR"
echo "📁 Done:   $DONE_DIR"
echo

# ensure npm registry
npm config set registry "$REGISTRY" >/dev/null 2>&1 || true

find "$CACHE_DIR" -maxdepth 1 -name "*.tgz" | while read -r file; do

  [ -f "$file" ] || continue

  base=$(basename "$file")

  echo "==============================="
  echo "📦 Processing $base"
  echo "==============================="

  # skip empty
  if [ ! -s "$file" ]; then
    echo "🔴 Empty file"
    rm -f "$file"
    continue
  fi

  # validate tarball quickly
  if ! tar -tzf "$file" >/dev/null 2>&1; then
    echo "🔴 Corrupted tarball"
    rm -f "$file"
    continue
  fi

  # extract package.json directly
  tmp=$(mktemp -d)

  if ! tar -xzf "$file" -C "$tmp" >/dev/null 2>&1; then
    echo "🔴 Extract failed"
    rm -rf "$tmp"
    continue
  fi

  pkgJson=$(find "$tmp" -name package.json | head -n 1)

  if [ ! -f "$pkgJson" ]; then
    echo "🔴 package.json missing"
    rm -rf "$tmp"
    continue
  fi

  name=$(jq -r '.name // empty' "$pkgJson" 2>/dev/null || true)
  version=$(jq -r '.version // empty' "$pkgJson" 2>/dev/null || true)

  rm -rf "$tmp"

  if [ -z "$name" ] || [ -z "$version" ]; then
    echo "🔴 Invalid metadata"
    continue
  fi

  echo "🔎 $name@$version"

  encoded=$(printf "%s" "$name" | sed 's/@/%40/g; s/\//%2F/g')

  # check exists with timeout
  exists=$(curl \
    --silent \
    --max-time 10 \
    "$REGISTRY/$encoded" 2>/dev/null || true)

  if echo "$exists" | jq -e ".versions[\"$version\"]" >/dev/null 2>&1; then
    echo "🔺 Already exists"

    mv "$file" "$DONE_DIR/$base"

    continue
  fi

  echo "🚀 Publishing..."

  set +e

output=$(npm publish "$file" \
  --registry "$REGISTRY" \
  --ignore-scripts \
  --no-audit \
  --no-fund \
  --provenance=false 2>&1)

  status=$?

  set -e

  if [ $status -eq 0 ]; then
    echo "🔼 Published"

    mv "$file" "$DONE_DIR/$base"

    continue
  fi

  if echo "$output" | grep -qi "previously published"; then
    echo "🔺 Already exists (race)"

    mv "$file" "$DONE_DIR/$base"

  elif echo "$output" | grep -qi "ENEEDAUTH"; then
    echo "🔒 Auth error"

  elif echo "$output" | grep -qi "E403"; then
    echo "🔒 Permission denied"

  elif echo "$output" | grep -qi "E404"; then
    echo "❌ Registry unreachable"

  else
    echo "❌ Publish failed"
    echo "$output"
  fi

  echo

done

echo
echo "✅ Push complete"