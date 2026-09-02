#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: Install these packages inside the Linux RunPod, not on the local Mac." >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: System package installation requires root inside the RunPod." >&2
  exit 1
fi

# These packages live on the Pod's container disk, not on /workspace. Run this
# idempotent bootstrap again after replacing or resetting the Pod container.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  libegl1 \
  libgl1 \
  libgles2 \
  libglu1-mesa \
  libxt6 \
  vulkan-tools

ldconfig

for library_name in libEGL.so.1 libGL.so.1 libGLU.so.1 libXt.so.6; do
  if ! ldconfig -p | grep -F "${library_name}" >/dev/null; then
    echo "ERROR: ${library_name} is still unavailable after package installation." >&2
    exit 1
  fi
done

echo "RunPod graphics system dependencies are installed."
