#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_tools git python3 curl

VALUES_FILE="${1:-${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/charts/values.yaml}"

failures=0

while IFS=$'\t' read -r project repo version; do
  [[ -n "${project:-}" ]] || continue
  [[ "${version}" == *"-alpha."* ]] || continue

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

  if ! git -C "${clone_dir}" merge-base --is-ancestor origin/master origin/dev >/dev/null 2>&1; then
    log "[${project}] STOP: master is not an ancestor of dev. Release creation is blocked."
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  fi

  if git -C "${clone_dir}" ls-remote --heads origin "${release_branch}" | grep -q .; then
    log "[${project}] release branch already exists: ${release_branch}"
    rm -rf "${clone_dir}"
    continue
  fi

  git -C "${clone_dir}" checkout -b "${release_branch}" origin/dev >/dev/null 2>&1 || {
    warn "[${project}] could not create release branch ${release_branch} from dev"
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  }

  git -C "${clone_dir}" push -u origin "${release_branch}" >/dev/null 2>&1 || {
    warn "[${project}] push of ${release_branch} failed"
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  }

  log "[${project}] created and pushed ${release_branch}"
  rm -rf "${clone_dir}"
done < <(bash "${SCRIPT_DIR}/discover-projects.sh" "${VALUES_FILE}")

if [[ "${failures}" -gt 0 ]]; then
  error "At least one project failed release creation. Review the logs above."
fi

log "Release creation completed for all eligible projects."
