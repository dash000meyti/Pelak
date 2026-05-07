#!/bin/sh

set -eu

REGISTRY="http://localhost:4873"

export NPM_CONFIG_PROVENANCE=false

BASE_DIR="./registry/packages"
TODO_DIR="$BASE_DIR/todo"
DONE_DIR="$BASE_DIR/done"

mkdir -p "$TODO_DIR" "$DONE_DIR"

echo "🚀 Pushing to Verdaccio..."
echo "🌐 Registry: $REGISTRY"
echo "📦 Source: $TODO_DIR"
echo "📁 Done:   $DONE_DIR"
echo

# ensure npm registry
npm config set registry "$REGISTRY" >/dev/null 2>&1 || true

for file in "$TODO_DIR"/*.tgz; do

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

  case "$output" in
    *previously\ published*|*cannot\ publish\ over\ previously\ published*)
    echo "🔺 Already exists (race)"

    mv "$file" "$DONE_DIR/$base"

    ;;
    *ENEEDAUTH*)
    echo "🔒 Auth error"

    ;;
    *E403*)
    echo "🔒 Permission denied"

    ;;
    *E404*)
    echo "❌ Registry unreachable"

    ;;
    *)
    echo "❌ Publish failed"
    echo "$output"
    ;;
  esac

  echo

done

echo
echo "✅ Push complete"