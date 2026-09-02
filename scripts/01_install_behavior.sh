#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runpod_env.sh"

bash "${SCRIPT_DIR}/00_install_system_deps.sh"
bash "${SCRIPT_DIR}/00_preflight_runpod.sh"

mkdir -p \
  "${CONDA_ENVS_PATH}" \
  "${CONDA_PKGS_DIRS}" \
  "${PIP_CACHE_DIR}" \
  "${HF_HOME}" \
  "${UV_CACHE_DIR}" \
  "${XDG_CACHE_HOME}" \
  "${DATA_ROOT}" \
  "${CHECKPOINT_ROOT}" \
  "${MODEL_ROOT}" \
  "${OUTPUT_ROOT}/logs"

if [[ ! -d "${PATH_TO_BEHAVIOR_1K}/.git" ]]; then
  git clone \
    --branch "${BEHAVIOR_VERSION}" \
    --depth 1 \
    https://github.com/StanfordVL/BEHAVIOR-1K.git \
    "${PATH_TO_BEHAVIOR_1K}"
else
  actual_version="$(git -C "${PATH_TO_BEHAVIOR_1K}" describe --tags --exact-match 2>/dev/null || true)"
  if [[ "${actual_version}" != "${BEHAVIOR_VERSION}" ]]; then
    echo "ERROR: Existing checkout is '${actual_version:-not on an exact tag}', expected ${BEHAVIOR_VERSION}." >&2
    echo "Refusing to modify an existing checkout automatically." >&2
    exit 1
  fi
fi

if [[ -d "${BEHAVIOR_ENV_PREFIX}" ]]; then
  echo "ERROR: Conda environment already exists at ${BEHAVIOR_ENV_PREFIX}." >&2
  echo "The installer will not overwrite it. Inspect the previous install before retrying." >&2
  exit 1
fi

# The official installer rejects pre-existing Isaac Sim path overrides.
unset EXP_PATH CARB_APP_PATH ISAAC_PATH

echo
echo "The official installer will now show three license agreements."
echo "Read them and answer the prompt yourself. No acceptance flags are automated here."
echo

cd "${PATH_TO_BEHAVIOR_1K}"
./setup.sh \
  --new-env behavior \
  --omnigibson \
  --bddl \
  --dataset \
  --cuda-version 12.8 \
  2>&1 | tee "${OUTPUT_ROOT}/logs/behavior-install.log"

echo
echo "Installation complete. Persistent environment: ${BEHAVIOR_ENV_PREFIX}"
echo "Next: bash ${VLA_REPO}/scripts/02_smoke_behavior.sh"
