#!/usr/bin/env bash
#
# Build and push the Bigcapital images from this repository.
#
# Usage:
#   ./scripts/publish-zr-images.sh                 # build + push :latest and :ghcrlocal
#   ./scripts/publish-zr-images.sh --no-push       # build only
#   ZR_TAG=v1.2.3 ./scripts/publish-zr-images.sh   # custom tag
#
# Why `git archive` instead of `docker build .`:
#   The repository contains two directories that differ only by letter case
#   (packages/server/src/modules/ee and .../EE). macOS filesystems cannot hold
#   both, so a build context taken from the working tree merges them and the
#   TypeScript build fails with TS2307. Streaming `git archive` into the build
#   gives Docker the real tree, exactly like the CI checkout on Linux.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

REGISTRY="${ZR_IMAGE_REGISTRY:-ghcr.io/zulfadliresources/bigcapital}"
TAG="${ZR_TAG:-ghcrlocal}"
ALSO_LATEST="${ZR_ALSO_LATEST:-true}"
PUSH=true

for arg in "$@"; do
  case "$arg" in
    --no-push) PUSH=false ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

TAGS=("$REGISTRY/NAME:$TAG")
if [ "$ALSO_LATEST" = "true" ]; then
  TAGS+=("$REGISTRY/NAME:latest")
fi

tag_args() {
  local name="$1"
  for t in "${TAGS[@]}"; do
    printf -- '-t\n%s\n' "${t/NAME/$name}"
  done
}

build() {
  local name="$1" dockerfile="$2"
  shift 2
  echo ""
  echo "==> Building $name (${TAGS[0]//NAME/$name})"
  # shellcheck disable=SC2046
  git archive --format=tar HEAD \
    | docker build \
        -f "$dockerfile" \
        $(tag_args "$name") \
        "$@" \
        -
}

if [ "$PUSH" = true ]; then
  echo "==> Logging in to $REGISTRY"
  echo "$REGISTRY" | grep -q '^ghcr.io' \
    && echo "    Use a GitHub PAT with 'write:packages' scope as the password."
  echo "${GHCR_TOKEN:-}" | docker login "$REGISTRY" -u "${GHCR_USER:-$(whoami)}" --password-stdin
fi

# Server must be built first: the migration image is layered on top of it.
build server ./packages/server/Dockerfile
build webapp ./packages/webapp/Dockerfile

# The migration image needs the local server tag as its base, so build it from
# the working tree with SERVER_IMAGE pointed at the tag we just produced.
echo ""
echo "==> Building migration (base: $REGISTRY/server:$TAG)"
# shellcheck disable=SC2046
git archive --format=tar HEAD \
  | docker build \
      -f docker/migration/Dockerfile \
      --build-arg SERVER_IMAGE="$REGISTRY/server:$TAG" \
      $(tag_args migration) \
      -

if [ "$PUSH" = true ]; then
  for name in server webapp migration; do
    for t in "${TAGS[@]}"; do
      ref="${t/NAME/$name}"
      echo "==> Pushing $ref"
      docker push "$ref"
    done
  done
  echo ""
  echo "Done. Images pushed to $REGISTRY"
else
  echo ""
  echo "Done (build only). Local tags:"
  for name in server webapp migration; do
    for t in "${TAGS[@]}"; do echo "  ${t/NAME/$name}"; done
  done
fi
