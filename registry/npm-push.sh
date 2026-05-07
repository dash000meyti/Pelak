#!/bin/sh

set -eu

REGISTRY="https://npm-registry.darkube.ir/"

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

  # read metadata from standard npm tarball location: package/package.json
  pkgMeta=$(tar -xOf "$file" package/package.json 2>/dev/null || true)

  if [ -z "$pkgMeta" ]; then
    echo "🔴 package.json missing"
    continue
  fi

  name=$(printf "%s" "$pkgMeta" | jq -r '.name // empty' 2>/dev/null || true)
  version=$(printf "%s" "$pkgMeta" | jq -r '.version // empty' 2>/dev/null || true)

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

  publish_tag=""
  case "$version" in
    *-*)
      publish_tag="--tag beta"
      ;;
  esac

output=$(npm publish "$file" \
  --registry "$REGISTRY" \
  --ignore-scripts \
  --no-audit \
  --no-fund \
  --provenance=false \
  $publish_tag 2>&1)

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