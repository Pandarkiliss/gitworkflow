#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_tools git python3 curl

VALUES_FILE="${1:-${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/charts/values.yaml}"
UMBRELLA_BRANCH="${UMBRELLA_RELEASE_BRANCH:-release/2026-s20}"
REPO_DIR="${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

failures=0

while IFS=$'\t' read -r project repo version; do
  [[ -n "${project:-}" ]] || continue
  if [[ "${version}" != *"-alpha."* && "${version}" != *"-beta."* ]]; then
    continue
  fi

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

  base_version="${version}"
  base_version="${base_version%-alpha.*}"
  base_version="${base_version%-beta.*}"
  beta_pattern="v${base_version}-beta.*"
  latest_beta="$(git -C "${clone_dir}" tag -l "${beta_pattern}" | sort -V | tail -n 1 || true)"

  if [[ -z "${latest_beta}" ]]; then
    new_beta_tag="v${base_version}-beta.1"
    log "[${project}] latest beta=none"
    log "[${project}] creating ${new_beta_tag}"
  else
    if ! git -C "${clone_dir}" merge-base --is-ancestor "${latest_beta}" "origin/${release_branch}" >/dev/null 2>&1; then
      log "[${project}] STOP: last beta ${latest_beta} is not an ancestor of ${release_branch}. Release branch diverged."
      failures=$((failures + 1))
      rm -rf "${clone_dir}"
      continue
    fi

    if git -C "${clone_dir}" diff --quiet "${latest_beta}^{tree}" "origin/${release_branch}^{tree}"; then
      log "[${project}] no content change since ${latest_beta}; skipping beta creation"
      rm -rf "${clone_dir}"
      continue
    fi

    last_number="${latest_beta##*-beta.}"
    next_number=$((last_number + 1))
    new_beta_tag="v${base_version}-beta.${next_number}"
    log "[${project}] latest beta=${latest_beta}"
    log "[${project}] creating ${new_beta_tag}"
  fi

  git -C "${clone_dir}" tag -a "${new_beta_tag}" "origin/${release_branch}" -m "Release ${new_beta_tag}" >/dev/null 2>&1 || {
    warn "[${project}] could not create tag ${new_beta_tag} on ${release_branch}"
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  }

  git -C "${clone_dir}" push origin "${new_beta_tag}" >/dev/null 2>&1 || {
    warn "[${project}] could not push tag ${new_beta_tag}"
    failures=$((failures + 1))
    rm -rf "${clone_dir}"
    continue
  }

  bash "${SCRIPT_DIR}/update-umbrella.sh" "${VALUES_FILE}" "${project}" "${new_beta_tag#v}" >/dev/null
  log "[${project}] umbrella updated"
  rm -rf "${clone_dir}"
done < <(bash "${SCRIPT_DIR}/discover-projects.sh" "${VALUES_FILE}")

if [[ "${failures}" -gt 0 ]]; then
  error "At least one project failed beta publication. Review the logs above."
fi

log "Beta publication completed."
