#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runpod_env.sh"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: This check must run inside the Linux RunPod, not on the local Mac." >&2
  exit 1
fi

if [[ ! -d "${VLA_WORKSPACE}" ]]; then
  echo "ERROR: ${VLA_WORKSPACE} does not exist. Check that the Network Volume is attached." >&2
  exit 1
fi

for command_name in nvidia-smi git curl conda; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${command_name}" >&2
    exit 1
  fi
done

probe_path="${VLA_WORKSPACE}/.vla-write-test-$$"
: > "${probe_path}"
rm -f "${probe_path}"

echo "== GPU =="
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader

echo
echo "== Persistent workspace =="
df -h "${VLA_WORKSPACE}"
if command -v findmnt >/dev/null 2>&1; then
  findmnt -T "${VLA_WORKSPACE}" || true
fi

echo
echo "== Runtime =="
python --version
conda --version
git --version

gpu_memory_mb="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | tr -d ' ')"
if [[ "${gpu_memory_mb}" =~ ^[0-9]+$ ]] && (( gpu_memory_mb < 45000 )); then
  echo
  echo "WARNING: Detected ${gpu_memory_mb} MiB VRAM. Simulator smoke tests may work,"
  echo "but the planned A6000 workflow expects roughly 48 GB VRAM."
fi

echo
echo "Preflight passed. ${VLA_WORKSPACE} is writable."

