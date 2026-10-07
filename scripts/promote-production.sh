#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_tools git python3 curl

VALUES_FILE="${1:-${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/charts/values.yaml}"
failures=0

while IFS=$'\t' read -r project repo version; do
  [[ -n "${project:-}" ]] || continue
  [[ "${version}" == *"-beta."* ]] || continue

  release_branch="$(version_to_release_branch "${version}")"
  log "[${project}] version=${version}"
  log "[${project}] release branch=${release_branch}"

  repo_url="$(gitlab_repo_url "${repo}")"
  clone_dir="$(mktemp -d)"

  if ! git clone --quiet "${repo_url}" "${clone_dir}"; then
    warn "[${project}] repository inaccessible: ${repo}"
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  fi

  git -C "${clone_dir}" fetch origin --prune --tags >/dev/null 2>&1 || true

  if ! git -C "${clone_dir}" merge-base --is-ancestor origin/master "origin/${release_branch}" >/dev/null 2>&1; then
    log "[${project}] STOP: master has evolved since the release branch was created. Merge master -> ${release_branch} and re-run qualification."
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  fi

  log "[${project}] promotion ready: ${release_branch} -> master"
  create_gitlab_merge_request "${release_branch}" "master" "Promote ${project} to production (${version})" "${repo}"
  rm -rf "${clone_dir}"
done < <(bash "${SCRIPT_DIR}/discover-projects.sh" "${VALUES_FILE}")

if [[ "${failures}" -gt 0 ]]; then
  error "At least one project failed production promotion checks."
fi

log "Promotion checks completed for all beta projects."
