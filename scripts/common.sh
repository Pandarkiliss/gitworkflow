#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s %s\n' "[$(date -u +%Y-%m-%dT%H:%M:%SZ)]" "$*"
}

warn() {
  log "WARN: $*"
}

error() {
  log "ERROR: $*" >&2
  exit 1
}

require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || error "Required tool not found: ${tool}"
  done
}

ensure_gitlab_token() {
  [[ -n "${GITLAB_RELEASE_TOKEN:-}" ]] || error "GITLAB_RELEASE_TOKEN is required. Configure it in GitLab CI/CD variables."
}

ensure_gitlab_host() {
  export GITLAB_HOST="${GITLAB_HOST:-${CI_SERVER_HOST:-gitlab.example.com}}"
  [[ -n "${GITLAB_HOST}" ]] || error "GitLab host cannot be empty. Set GITLAB_HOST or CI_SERVER_HOST."
}

gitlab_api_url() {
  ensure_gitlab_host
  local base="${GITLAB_API_URL:-https://${GITLAB_HOST}/api/v4}"
  printf '%s' "$base"
}

gitlab_repo_url() {
  local repo_path="${1:?usage: gitlab_repo_url <project-path>}"
  ensure_gitlab_token
  ensure_gitlab_host
  printf '%s' "https://gitlab-ci-token:${GITLAB_RELEASE_TOKEN}@${GITLAB_HOST}/${repo_path}.git"
}

version_to_release_branch() {
  local version="${1:?usage: version_to_release_branch <version>}"
  local base="${version}"
  base="${base%-alpha.*}"
  base="${base%-beta.*}"
  local major="${base%%.*}"
  local minor="${base#*.}"
  minor="${minor%%.*}"
  printf '%s' "release/${major}.${minor}"
}

gitlab_api() {
  local method="${1:?usage: gitlab_api <method> <endpoint> [body]}"
  local endpoint="${2:?usage: gitlab_api <method> <endpoint> [body]}"
  local body="${3:-}"
  local headers=()
  local curl_args=(--silent --show-error --fail --request "$method")

  ensure_gitlab_token

  headers+=(--header "PRIVATE-TOKEN: ${GITLAB_RELEASE_TOKEN}")
  curl_args+=("${headers[@]}")

  if [[ -n "$body" ]]; then
    curl_args+=(--header "Content-Type: application/json" --data "$body")
  fi

  curl "${curl_args[@]}" "$(gitlab_api_url)/${endpoint}"
}

create_gitlab_merge_request() {
  local source_branch="${1:?usage: create_gitlab_merge_request <source_branch> <target_branch> <title> [project_path]}"
  local target_branch="${2:?usage: create_gitlab_merge_request <source_branch> <target_branch> <title> [project_path]}"
  local title="${3:?usage: create_gitlab_merge_request <source_branch> <target_branch> <title> [project_path]}"
  local project_path="${4:-${GITLAB_PROJECT_PATH:-${CI_PROJECT_PATH:-}}}"

  if [[ -z "$project_path" ]]; then
    log "No GitLab project path configured for automatic MR. Manual MR required: ${source_branch} -> ${target_branch}"
    return 0
  fi

  local body
  body="$(python3 - "$source_branch" "$target_branch" "$title" <<'PY'
import json, sys
source_branch, target_branch, title = sys.argv[1:4]
print(json.dumps({
    'source_branch': source_branch,
    'target_branch': target_branch,
    'title': title,
    'remove_source_branch': True,
}))
PY
)"

  local encoded_project_path
  encoded_project_path="$(python3 - "$project_path" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=''))
PY
)"

  log "Creating GitLab Merge Request for ${project_path}: ${source_branch} -> ${target_branch}"
  gitlab_api POST "projects/${encoded_project_path}/merge_requests" "$body" || warn "Merge request creation failed; manual MR is still required."
}
