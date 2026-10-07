#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

VALUES_FILE="${1:-${CI_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/charts/values.yaml}"

python3 - "$VALUES_FILE" <<'PY'
import sys
from pathlib import Path
import yaml

values_file = Path(sys.argv[1])
with values_file.open('r', encoding='utf-8') as fh:
    data = yaml.safe_load(fh) or {}

if not isinstance(data, dict):
    raise SystemExit(f'{values_file}: root element must be a mapping')

for key, value in sorted(data.items()):
    if key == 'global' or not isinstance(value, dict):
        continue
    repo = str((value.get('repository-name') or '')).strip()
    tag = str((value.get('deployment', {}).get('image', {}).get('tag') or '')).strip()
    if repo and tag:
        print(f"{key}\t{repo}\t{tag}")
PY
