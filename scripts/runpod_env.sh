#!/usr/bin/env bash

# Shared paths for RunPod. Source this file from other scripts.
export VLA_WORKSPACE="${VLA_WORKSPACE:-/workspace}"
export VLA_REPO="${VLA_REPO:-${VLA_WORKSPACE}/VLA_test}"
export BEHAVIOR_VERSION="${BEHAVIOR_VERSION:-v3.9.2}"
export PATH_TO_BEHAVIOR_1K="${PATH_TO_BEHAVIOR_1K:-${VLA_WORKSPACE}/BEHAVIOR-1K}"

# Keep the environment and package caches on the persistent network volume.
export CONDA_ENVS_PATH="${CONDA_ENVS_PATH:-${VLA_WORKSPACE}/environments/conda/envs}"
export CONDA_PKGS_DIRS="${CONDA_PKGS_DIRS:-${VLA_WORKSPACE}/environments/conda/pkgs}"
export BEHAVIOR_ENV_PREFIX="${BEHAVIOR_ENV_PREFIX:-${CONDA_ENVS_PATH}/behavior}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-${VLA_WORKSPACE}/environments/cache/pip}"
export HF_HOME="${HF_HOME:-${VLA_WORKSPACE}/environments/cache/huggingface}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-${VLA_WORKSPACE}/environments/cache/uv}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${VLA_WORKSPACE}/environments/cache/xdg}"

export DATA_ROOT="${DATA_ROOT:-${VLA_WORKSPACE}/datasets/2026-challenge-demos}"
export CHECKPOINT_ROOT="${CHECKPOINT_ROOT:-${VLA_WORKSPACE}/checkpoints}"
export MODEL_ROOT="${MODEL_ROOT:-${VLA_WORKSPACE}/models}"
export OUTPUT_ROOT="${OUTPUT_ROOT:-${VLA_WORKSPACE}/outputs}"

