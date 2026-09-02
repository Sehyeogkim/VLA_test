#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runpod_env.sh"

TASK_ID="${1:-0}"
if ! [[ "${TASK_ID}" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 TASK_ID" >&2
  echo "Example: $0 0" >&2
  exit 1
fi

if [[ ! -x "${BEHAVIOR_ENV_PREFIX}/bin/python" ]]; then
  echo "ERROR: Missing BEHAVIOR environment. Run the installer first." >&2
  exit 1
fi

chunk="$(printf 'chunk-%03d' "${TASK_ID}")"
mkdir -p "${DATA_ROOT}"

"${BEHAVIOR_ENV_PREFIX}/bin/python" -m pip install --upgrade huggingface_hub

HF_CLI="${BEHAVIOR_ENV_PREFIX}/bin/hf"
if [[ ! -x "${HF_CLI}" ]]; then
  echo "ERROR: Hugging Face CLI was not installed at ${HF_CLI}." >&2
  exit 1
fi

echo "Downloading only task ${TASK_ID} (${chunk}) into ${DATA_ROOT}."
"${HF_CLI}" download behavior-1k/2026-challenge-demos \
  --repo-type dataset \
  --local-dir "${DATA_ROOT}" \
  --include "data/${chunk}/**" \
  --include "meta/episodes/${chunk}/**" \
  --include "videos/*/${chunk}/**" \
  --include "meta/info.json" \
  --include "meta/stats.json" \
  --include "meta/tasks.parquet"

echo
du -sh "${DATA_ROOT}"
echo "Task download complete."

