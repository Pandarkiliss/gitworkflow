#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_tools git python3

VALUES_FILE="${1:-${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/charts/values.yaml}"
PROJECT="${2:?usage: update-umbrella.sh <values.yaml> <project> <tag>}"
NEW_TAG="${3:?usage: update-umbrella.sh <values.yaml> <project> <tag>}"

REPO_DIR="${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
UMBRELLA_BRANCH="${UMBRELLA_RELEASE_BRANCH:-release/2026-s20}"

if ! git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "Current directory is not a Git repository: ${REPO_DIR}"
fi

git -C "${REPO_DIR}" fetch origin --prune >/dev/null 2>&1 || true

if git -C "${REPO_DIR}" show-ref --verify --quiet "refs/remotes/origin/${UMBRELLA_BRANCH}"; then
  git -C "${REPO_DIR}" checkout -B "${UMBRELLA_BRANCH}" "origin/${UMBRELLA_BRANCH}" >/dev/null 2>&1 || git -C "${REPO_DIR}" checkout "${UMBRELLA_BRANCH}"
else
  git -C "${REPO_DIR}" checkout -B "${UMBRELLA_BRANCH}" >/dev/null 2>&1 || git -C "${REPO_DIR}" checkout "${UMBRELLA_BRANCH}"
fi

python3 - "$VALUES_FILE" "$PROJECT" "$NEW_TAG" <<'PY'
import sys
from pathlib import Path
import yaml

values_file = Path(sys.argv[1])
project = sys.argv[2]
new_tag = sys.argv[3]

with values_file.open('r', encoding='utf-8') as fh:
    data = yaml.safe_load(fh) or {}

if not isinstance(data, dict):
    raise SystemExit(f'{values_file}: root element must be a YAML mapping')

if project not in data:
    raise SystemExit(f'Project {project!r} not found in {values_file}')

project_cfg = data[project]
if not isinstance(project_cfg, dict):
    raise SystemExit(f'Project {project!r} is not a mapping')

image = project_cfg.get('deployment', {}).get('image', {})
image['tag'] = new_tag

with values_file.open('w', encoding='utf-8') as fh:
    yaml.safe_dump(data, fh, sort_keys=False, default_flow_style=False)
PY

rel_values_file="${VALUES_FILE#${REPO_DIR}/}"
if [[ "${rel_values_file}" == "${VALUES_FILE}" ]]; then
  rel_values_file="charts/values.yaml"
fi

if git -C "${REPO_DIR}" diff --quiet -- "${rel_values_file}"; then
  log "No umbrella change needed for ${PROJECT}."
  exit 0
fi

git -C "${REPO_DIR}" add "${rel_values_file}"
git -C "${REPO_DIR}" commit -m "chore: update ${PROJECT} to ${NEW_TAG}"
if ! git -C "${REPO_DIR}" push origin "${UMBRELLA_BRANCH}"; then
  error "Could not push update to umbrella release branch ${UMBRELLA_BRANCH}."
fi

log "Updated umbrella release branch ${UMBRELLA_BRANCH} with ${PROJECT} -> ${NEW_TAG}"
