#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runpod_env.sh"

if [[ ! -x "${BEHAVIOR_ENV_PREFIX}/bin/python" ]]; then
  echo "ERROR: Missing BEHAVIOR Python: ${BEHAVIOR_ENV_PREFIX}/bin/python" >&2
  exit 1
fi

bash "${SCRIPT_DIR}/00_preflight_runpod.sh"

export OMNI_KIT_ACCEPT_EULA=YES
export OMNIGIBSON_HEADLESS=1
export OMNIGIBSON_GPU_ID="${OMNIGIBSON_GPU_ID:-0}"
export R1PRO_VISUAL_OUTPUT_DIR="${R1PRO_VISUAL_OUTPUT_DIR:-${OUTPUT_ROOT}/visuals/r1pro_cached_task}"

mkdir -p "${OUTPUT_ROOT}/logs" "${R1PRO_VISUAL_OUTPUT_DIR}"

echo "Capturing real Isaac Sim viewer and robot-sensor images to ${R1PRO_VISUAL_OUTPUT_DIR}"
"${BEHAVIOR_ENV_PREFIX}/bin/python" "${SCRIPT_DIR}/04_capture_r1pro_visuals.py" \
  2>&1 | tee "${OUTPUT_ROOT}/logs/r1pro-visual-capture.log"

echo
echo "Visual capture complete: ${R1PRO_VISUAL_OUTPUT_DIR}"
