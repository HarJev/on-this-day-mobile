#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_url="${ON_THIS_DAY_API_BASE_URL:-}"

if [[ ! "$api_url" =~ ^https://[^/]+ ]]; then
  echo "Set ON_THIS_DAY_API_BASE_URL to the deployed HTTPS API URL." >&2
  exit 1
fi

if [[ ! -f "$repo_dir/android/key.properties" ]]; then
  echo "Add the private Android upload-key settings to android/key.properties." >&2
  exit 1
fi

cd "$repo_dir"
flutter build appbundle --release \
  --dart-define="ON_THIS_DAY_API_BASE_URL=$api_url" "$@"
