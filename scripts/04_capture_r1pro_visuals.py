#!/usr/bin/env python3
"""Capture real Isaac Sim renders from the official cached R1Pro task."""

from __future__ import annotations

import json
import math
import os
import re
from pathlib import Path
from typing import Any

import imageio.v2 as imageio
import numpy as np
import yaml
from PIL import Image, ImageOps

import omnigibson as og
from omnigibson.macros import gm


gm.ENABLE_OBJECT_STATES = True
gm.USE_GPU_DYNAMICS = False

OUTPUT_DIR = Path(os.environ.get("R1PRO_VISUAL_OUTPUT_DIR", "/workspace/outputs/visuals/r1pro_cached_task"))
VIDEO_STEPS = int(os.environ.get("R1PRO_VIDEO_STEPS", "60"))
VIDEO_FPS = int(os.environ.get("R1PRO_VIDEO_FPS", "10"))


def as_numpy(value: Any) -> np.ndarray:
    """Convert torch/numpy-like observation values without importing torch."""
    if hasattr(value, "detach"):
        value = value.detach()
    if hasattr(value, "cpu"):
        value = value.cpu()
    if hasattr(value, "numpy"):
        value = value.numpy()
    return np.asarray(value)


def safe_name(parts: list[str]) -> str:
    name = "__".join(parts)
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", name).strip("_")


def rgb_to_uint8(array: np.ndarray) -> np.ndarray:
    rgb = np.asarray(array)
    if rgb.ndim != 3 or rgb.shape[-1] < 3:
        raise ValueError(f"Expected HxWxC RGB array, got {rgb.shape}")
    rgb = rgb[..., :3]
    if np.issubdtype(rgb.dtype, np.floating):
        finite = rgb[np.isfinite(rgb)]
        low = float(finite.min()) if finite.size else 0.0
        high = float(finite.max()) if finite.size else 1.0
        if low >= 0.0 and high <= 1.0:
            rgb = rgb * 255.0
        elif low >= -1.0 and high <= 1.0:
            rgb = (rgb + 1.0) * 127.5
    return np.nan_to_num(rgb, nan=0.0, posinf=255.0, neginf=0.0).clip(0, 255).astype(np.uint8)


def save_depth_colormap(array: np.ndarray, path: Path) -> dict[str, float | None]:
    depth = np.asarray(array).squeeze()
    if depth.ndim != 2:
        raise ValueError(f"Expected HxW depth array, got {depth.shape}")

    finite_mask = np.isfinite(depth)
    finite = depth[finite_mask]
    if finite.size:
        near = float(np.percentile(finite, 1))
        far = float(np.percentile(finite, 99))
        if math.isclose(near, far):
            far = near + 1.0
        normalized = np.zeros_like(depth, dtype=np.float32)
        normalized[finite_mask] = np.clip((depth[finite_mask] - near) / (far - near), 0.0, 1.0)
        gray = ((1.0 - normalized) * 255.0).astype(np.uint8)
        gray[~finite_mask] = 0
    else:
        near = None
        far = None
        gray = np.zeros(depth.shape, dtype=np.uint8)

    colored = ImageOps.colorize(Image.fromarray(gray, mode="L"), black="#071330", white="#fff3a3")
    colored.save(path)
    return {"display_near": near, "display_far": far}


def array_summary(array: np.ndarray) -> dict[str, Any]:
    result: dict[str, Any] = {"shape": list(array.shape), "dtype": str(array.dtype)}
    if np.issubdtype(array.dtype, np.number):
        finite = array[np.isfinite(array)]
        result["finite_count"] = int(finite.size)
        result["min"] = float(finite.min()) if finite.size else None
        result["max"] = float(finite.max()) if finite.size else None
    return result


def save_observation_tree(value: Any, parts: list[str], metadata: dict[str, Any]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            save_observation_tree(child, [*parts, str(key)], metadata)
        return

    try:
        array = as_numpy(value)
    except Exception as exc:  # noqa: BLE001 - metadata should survive one unsupported value
        metadata["/".join(parts)] = {"error": f"{type(exc).__name__}: {exc}"}
        return

    key = "/".join(parts)
    summary = array_summary(array)
    lower_key = key.lower()
    stem = safe_name(parts)

    try:
        if "rgb" in lower_key and array.ndim == 3 and array.shape[-1] >= 3:
            filename = f"obs__{stem}.png"
            Image.fromarray(rgb_to_uint8(array), mode="RGB").save(OUTPUT_DIR / filename)
            summary["visual_file"] = filename
        elif "depth" in lower_key and array.squeeze().ndim == 2:
            filename = f"depth__{stem}.png"
            summary.update(save_depth_colormap(array, OUTPUT_DIR / filename))
            summary["visual_file"] = filename
        elif "proprio" in lower_key:
            filename = f"proprio__{stem}.npy"
            np.save(OUTPUT_DIR / filename, array)
            summary["data_file"] = filename
    except Exception as exc:  # noqa: BLE001 - keep all other captures if one modality fails
        summary["save_error"] = f"{type(exc).__name__}: {exc}"

    metadata[key] = summary


def viewer_frame(camera_mover: Any) -> np.ndarray:
    return rgb_to_uint8(as_numpy(camera_mover.get_image()))


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    config_path = Path(og.example_config_path) / "r1pro_behavior.yaml"
    with config_path.open("r", encoding="utf-8") as config_file:
        config = yaml.load(config_file, Loader=yaml.FullLoader)

    config["task"]["online_object_sampling"] = False
    config["task"]["use_presampled_robot_pose"] = True
    config["render"]["viewer_width"] = 1280
    config["render"]["viewer_height"] = 720

    metadata: dict[str, Any] = {
        "source_config": str(config_path),
        "scene_model": config["scene"]["scene_model"],
        "activity_name": config["task"]["activity_name"],
        "activity_definition_id": config["task"]["activity_definition_id"],
        "activity_instance_id": config["task"]["activity_instance_id"],
        "robot_type": config["robots"][0]["type"],
        "viewer_resolution": [config["render"]["viewer_width"], config["render"]["viewer_height"]],
        "requested_video_steps": VIDEO_STEPS,
        "video_fps": VIDEO_FPS,
        "observations": {},
    }

    env = None
    video_writer = None
    captured_steps = 0
    try:
        env = og.Environment(configs=config)
        og.sim.viewer_camera.set_position_orientation(
            position=[1.6, 6.15, 1.5],
            orientation=[-0.2322, 0.5895, 0.7199, -0.2835],
        )
        camera_mover = og.sim.enable_viewer_camera_teleoperation()
        env.reset()

        camera_mover.record_image(str(OUTPUT_DIR / "scene_r1pro_before.png"))

        video_path = OUTPUT_DIR / "random_action_episode.mp4"
        try:
            video_writer = imageio.get_writer(video_path, fps=VIDEO_FPS, codec="libx264", quality=8)
        except Exception as exc:  # noqa: BLE001
            metadata["video_error"] = f"{type(exc).__name__}: {exc}"
            video_writer = None

        first_state = None
        for step_index in range(VIDEO_STEPS):
            action = env.robots[0].action_space.sample()
            state, reward, terminated, truncated, info = env.step(action * 0.1)
            captured_steps = step_index + 1
            if first_state is None:
                first_state = state
                metadata["first_step_reward"] = float(reward)

            frame = viewer_frame(camera_mover)
            if video_writer is not None:
                video_writer.append_data(frame)
            elif step_index in {0, VIDEO_STEPS // 2, VIDEO_STEPS - 1}:
                Image.fromarray(frame, mode="RGB").save(OUTPUT_DIR / f"episode_frame_{step_index:03d}.png")

            if terminated or truncated:
                metadata["episode_finished_at_step"] = captured_steps
                metadata["terminated"] = bool(terminated)
                metadata["truncated"] = bool(truncated)
                break

        if video_writer is not None:
            video_writer.close()
            video_writer = None
            metadata["video_file"] = video_path.name

        camera_mover.record_image(str(OUTPUT_DIR / "scene_r1pro_after.png"))
        if first_state is not None:
            save_observation_tree(first_state, ["state"], metadata["observations"])

        metadata["captured_steps"] = captured_steps
        metadata["files"] = sorted(path.name for path in OUTPUT_DIR.iterdir() if path.is_file())
        with (OUTPUT_DIR / "capture_metadata.json").open("w", encoding="utf-8") as metadata_file:
            json.dump(metadata, metadata_file, indent=2, sort_keys=True)

        print(f"Capture complete: {OUTPUT_DIR}")
        for output_path in sorted(OUTPUT_DIR.iterdir()):
            if output_path.is_file():
                print(f"  {output_path.name}: {output_path.stat().st_size} bytes")
    finally:
        if video_writer is not None:
            video_writer.close()
        if env is not None:
            og.shutdown()


if __name__ == "__main__":
    main()
