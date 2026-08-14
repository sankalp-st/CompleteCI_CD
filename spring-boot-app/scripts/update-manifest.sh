#!/usr/bin/env bash
set -euo pipefail

TAG="$1"
GITHUB_TOKEN="${2:-}"

ROOT_DIR="$(dirname "$0")/.."
MANIFEST="$ROOT_DIR/../spring-boot-app-manifests/deployment.yaml"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag> [github_token]"
  exit 1
fi

IMAGE="your-dockerhub-username/demo-app:$TAG"

echo "Updating manifest $MANIFEST -> image: $IMAGE"
sed -i "s|image: .*|image: ${IMAGE}|" "$MANIFEST"

git config user.email "jenkins@example.com"
git config user.name "jenkins"
git add "$MANIFEST"
git commit -m "ci: update image tag to $TAG" || echo "no changes to commit"

if [ -n "$GITHUB_TOKEN" ]; then
  echo "Pushing via token"
  git push "https://${GITHUB_TOKEN}@github.com/<your-org>/<your-repo>.git" HEAD:main
else
  git push || echo "Push failed - provide GITHUB_TOKEN to push from CI"
fi
