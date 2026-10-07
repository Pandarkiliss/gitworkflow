#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

usage() {
  echo "Usage: $0 <method> <endpoint> [json-body]" >&2
  exit 1
}

[[ $# -ge 2 ]] || usage

method="${1}"
endpoint="${2}"
body="${3:-}"

if [[ -n "${body}" ]]; then
  gitlab_api "${method}" "${endpoint}" "${body}"
else
  gitlab_api "${method}" "${endpoint}"
fi
