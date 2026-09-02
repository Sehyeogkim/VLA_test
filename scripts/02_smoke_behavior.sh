#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runpod_env.sh"

if [[ ! -d "${BEHAVIOR_ENV_PREFIX}" ]]; then
  echo "ERROR: Missing environment: ${BEHAVIOR_ENV_PREFIX}" >&2
  echo "Run scripts/01_install_behavior.sh first." >&2
  exit 1
fi

mkdir -p "${OUTPUT_ROOT}/logs"

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${BEHAVIOR_ENV_PREFIX}"

export OMNI_KIT_ACCEPT_EULA=YES
export OMNIGIBSON_HEADLESS=1
export OMNIGIBSON_GPU_ID="${OMNIGIBSON_GPU_ID:-0}"

echo "Running the official cached R1Pro BEHAVIOR example for one 100-step episode."
echo "The script scales random actions to 10% of the action range."

python - <<'PY' 2>&1 | tee "${OUTPUT_ROOT}/logs/r1pro-smoke.log"
from omnigibson.examples.environments import behavior_env_demo

# Select the pre-sampled cached task automatically and avoid an interactive UI prompt.
behavior_env_demo.choose_from_options = lambda **_: False
behavior_env_demo.main(headless=True, short_exec=True)
PY

echo
echo "Smoke test complete. Log: ${OUTPUT_ROOT}/logs/r1pro-smoke.log"

