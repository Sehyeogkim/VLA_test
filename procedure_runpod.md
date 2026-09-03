# RunPod BEHAVIOR-1K 완전 재현 절차

마지막 검증일: 2026-09-02
검증 장비: RunPod Secure Cloud, NVIDIA A40 48GB

이 문서는 비어 있는 새 RunPod 환경에서 BEHAVIOR-1K를 설치하고 R1Pro smoke test까지 재현하기 위한 기준 문서다. 설치 순서를 바꾸거나 기존 Python 환경에 임의로 패키지를 추가하지 않는다.

## 1. 현재까지 검증된 결과

| 항목 | 검증 결과 |
| --- | --- |
| Pod | RunPod Secure Cloud, A40 48GB |
| GPU VRAM | 46,068 MiB |
| NVIDIA driver | 580.159.04 |
| 그래픽 API | Vulkan, NVIDIA A40 인식 성공 |
| Persistent storage | 250GB Volume disk, `/workspace`에 마운트 |
| Container image | `runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404` |
| BEHAVIOR-1K | `v3.9.2` |
| OmniGibson | 3.9.2 |
| Isaac Sim | 5.1 |
| 평가 환경 Python | 3.11.16 |
| 평가 환경 PyTorch | 2.7.0+cu128 |
| 로봇 | R1Pro |
| smoke test | 공식 cached task 환경에서 random action 최대 100 step, 정상 종료 |
| visual capture | 실제 viewer PNG, 카메라별 RGB/Depth, 60-step MP4 저장 성공 |
| 첫 실행 시간 | 약 14분 38초 |
| 현재 Pod 상태 | `EXITED`; GPU 과금 중지, persistent storage 유지 |

설치 후 관측한 용량은 다음과 같다.

```text
/workspace/BEHAVIOR-1K     약 100GB
/workspace/environments   약 44GB
/workspace/outputs        약 2.2MB
```

## 2. 이번 테스트가 정확히 검증한 범위

공식 `r1pro_behavior.yaml`과 `behavior_env_demo.py`를 사용했다.

| 항목 | 실제 값 |
| --- | --- |
| scene | `house_double_floor_lower` |
| rooms | `living_room`, `kitchen` |
| task | `picking_up_trash` |
| activity definition | `0` |
| activity instance | `0` |
| scene 생성 | 공식 pre-sampled cached scene |
| robot | `R1Pro` |
| observation 설정 | RGB + Depth, 128×128 |
| action | normalized continuous random action × 0.1 |
| grasping | `physical` |
| episode | reset 1회, 최대 100 step |

실제로 확인한 것은 다음이다.

- Isaac Sim과 OmniGibson 실행
- A40 Vulkan 렌더러 인식
- BEHAVIOR scene/object/robot asset 로딩
- cached task instance와 R1Pro 생성
- controller 및 RGB/Depth 센서 초기화
- `env.reset()` 및 `env.step(action)` 반복 실행
- 물리 시뮬레이션 후 정상 종료
- 1280×720 viewer 이미지 전/후 저장
- 외부, 머리 ZED, 좌·우 손목 카메라의 RGB/Depth 저장
- 82차원 `low_dim` 상태 관측 확인
- 60 random-action step을 10fps MP4로 저장

아직 확인하지 않은 것은 다음이다.

- `picking_up_trash` task 성공 여부
- action vector의 차원과 각 요소 의미
- 기본 정책 또는 VLA checkpoint 추론
- 공식 demonstration trajectory
- 성공률, reward, task progress

따라서 현재 결과는 **simulator 실행과 observation/action 경로를 검증한 smoke test**이며, task 성공 또는 VLA 성능 평가는 아직 아니다.

## 3. Pod 생성 설정

### 권장 하드웨어

- GPU: A40 48GB, RTX A6000 48GB, RTX 6000 Ada 48GB 또는 L40S 48GB
- 첫 검증에서 A40 48GB로 정상 실행됨
- CPU RAM: 최소 32GB, 가능하면 64GB 이상
- Persistent storage: 250GB 이상. 새 구축에서는 독립 Network Volume 권장
- Cloud: 가능하면 Secure Cloud
- Container disk: 100GB

Pod 템플릿 또는 이미지:

```text
runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404
```

Pod 환경 변수:

```text
NVIDIA_DRIVER_CAPABILITIES=all
NVIDIA_VISIBLE_DEVICES=all
```

포트:

```text
8888/http
22/tcp
```

Persistent storage는 `/workspace`에 마운트한다. 장기간 재사용할 환경은 Pod 생성 화면에서 `Network volume`을 선택하고, 이미 만든 Network Volume을 연결한다. Pod와 Network Volume은 같은 데이터센터에 있어야 한다.

## 4. 저장공간 수명 구분

반드시 다음 구분을 기억한다.

| 종류/위치 | 용도 | Pod Stop 후 | 다른 Pod에서 재사용 |
| --- | --- | --- | --- |
| Volume disk의 `/workspace` | 코드, Conda, assets, 데이터, 모델, 결과 | 유지 | 특정 호스트에 묶이므로 migration 필요 |
| Network Volume의 `/workspace` | 같은 용도의 독립 저장공간 | 유지 | 같은 데이터센터의 호환 Pod에 다시 연결 가능 |
| `/root`, `/tmp`, `/opt` | 임시 파일 및 OS package | 보존을 가정하지 않음 | 불가 |
| Container의 apt package | EGL/GL/Vulkan system library | reset/redeploy 후 재설치 필요 | 불가 |

`Stop`은 GPU를 중지하지만 persistent storage 비용은 계속 발생한다. Volume disk는 Pod에 종속되므로 Pod를 `Terminate`하면 함께 삭제된다. Network Volume은 Pod와 독립된 리소스여서 Pod를 종료해도 남지만, Network Volume 자체를 삭제하면 데이터가 사라진다.

이번 2026-09-02 최초 설치는 화면상 `/workspace`가 영속적이었지만 실제 유형은 **Network Volume이 아니라 250GB Volume disk**였다. 원래 A40 호스트의 자리가 사라져 자동 Pod migration으로 새 A40 호스트에 데이터를 복사해야 했다. 다음 완전 신규 구축에서는 RunPod `Storage`에서 Network Volume을 먼저 만들거나, Pod 배포 화면에서 `Persistent storage: Network volume`과 기존 볼륨을 명시적으로 선택한다.

## 5. 로컬 SSH 키 준비

Mac에서 한 번만 실행한다.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_runpod -C "runpod"
chmod 600 ~/.ssh/id_ed25519_runpod
```

RunPod 계정에는 다음 공개키의 내용만 등록한다.

```bash
cat ~/.ssh/id_ed25519_runpod.pub
```

개인키 `~/.ssh/id_ed25519_runpod`의 내용은 GitHub, 채팅 또는 문서에 복사하지 않는다.

Pod가 Running 상태가 되면 RunPod `Connect` 화면의 현재 SSH 명령을 사용한다.

```bash
ssh -t <POD별-SSH-USER>@ssh.runpod.io -i ~/.ssh/id_ed25519_runpod
```

PTY 오류가 나오면 `-tt`를 사용한다.

```bash
ssh -tt <POD별-SSH-USER>@ssh.runpod.io -i ~/.ssh/id_ed25519_runpod
```

상세 문제 해결은 `runpod_connect.md`를 참고한다.

## 6. 완전히 새 Volume에서 최초 설치

이 절차는 `/workspace`가 비어 있을 때 한 번 실행한다.

### 6.1 GPU와 mount 확인

```bash
nvidia-smi
df -h /workspace
pwd
```

확인 기준:

- `nvidia-smi`에 선택한 GPU가 표시됨
- `/workspace`가 persistent storage로 마운트됨
- 모든 후속 파일을 `/workspace`에 저장함

### 6.2 저장소 clone

```bash
cd /workspace
git clone https://github.com/Sehyeogkim/VLA_test.git
cd /workspace/VLA_test
```

이미 저장소가 있으면 clone하지 않는다.

```bash
cd /workspace/VLA_test
git pull --ff-only
```

### 6.3 Miniforge 설치

RunPod 기본 Python에 BEHAVIOR 의존성을 직접 설치하지 않는다. Miniforge 자체도 persistent storage에 설치한다.

```bash
mkdir -p /workspace/environments
curl -L \
  -o /tmp/Miniforge3-25.3.1-0-Linux-x86_64.sh \
  https://github.com/conda-forge/miniforge/releases/download/25.3.1-0/Miniforge3-25.3.1-0-Linux-x86_64.sh
echo "376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768  /tmp/Miniforge3-25.3.1-0-Linux-x86_64.sh" \
  | sha256sum --check
bash /tmp/Miniforge3-25.3.1-0-Linux-x86_64.sh \
  -b \
  -p /workspace/environments/miniforge3
source /workspace/VLA_test/scripts/runpod_env.sh
conda --version
```

검증된 설치 위치:

```text
/workspace/environments/miniforge3
```

재현성을 위해 실제 사용한 Miniforge `25.3.1-0` installer와 SHA-256을 고정했다. 자동으로 `latest`를 사용하지 않는다.

`conda --version`이 실패하면 다음 단계로 넘어가지 않는다.

### 6.4 그래픽 system package 설치

```bash
cd /workspace/VLA_test
bash scripts/00_install_system_deps.sh
```

설치되는 핵심 패키지:

- `libegl1`
- `libgl1`
- `libgles2`
- `libglu1-mesa`
- `libxt6`
- `vulkan-tools`

이 단계는 idempotent하므로 다시 실행해도 된다.

### 6.5 Preflight

```bash
bash scripts/00_preflight_runpod.sh
```

통과 기준:

- GPU 이름과 VRAM 출력
- `vulkaninfo`에서 NVIDIA GPU 출력
- `/workspace` 쓰기 성공
- Conda와 Git 출력
- 마지막 줄에 다음 메시지 출력

```text
Preflight passed. /workspace is writable.
```

### 6.6 BEHAVIOR 공식 설치

```bash
cd /workspace/VLA_test
bash scripts/01_install_behavior.sh
```

이 스크립트가 실행하는 공식 설치 옵션:

```bash
./setup.sh \
  --new-env behavior \
  --omnigibson \
  --bddl \
  --dataset \
  --cuda-version 12.8
```

설치 중 다음 세 종류의 약관이 표시될 수 있다.

1. Conda 관련 약관
2. NVIDIA Isaac Sim EULA
3. BEHAVIOR data bundle 약관

약관은 사용자가 직접 읽고 동의한다. 자동 수락하지 않는다.

중요: 여기의 `--dataset`은 시뮬레이터 장면·물체·로봇 asset 설치다. Hugging Face의 수 TB 규모 demonstration dataset 전체 다운로드가 아니다.

완료 경로:

```text
/workspace/BEHAVIOR-1K
/workspace/environments/conda/envs/behavior
/workspace/outputs/logs/behavior-install.log
```

설치가 완료된 환경이 이미 있으면 `01_install_behavior.sh`를 다시 실행하지 않는다. 스크립트는 기존 환경을 덮어쓰지 않도록 중단한다.

## 7. R1Pro smoke test

```bash
cd /workspace/VLA_test
bash scripts/02_smoke_behavior.sh
```

스크립트는 base Python이 아니라 다음 interpreter를 명시적으로 사용한다.

```text
/workspace/environments/conda/envs/behavior/bin/python
```

첫 실행에서는 shader, collision mesh와 TorchInductor cache 생성 때문에 10~20분 이상 출력이 멈춘 것처럼 보일 수 있다. 다음 로그가 보이고 프로세스가 살아 있다면 기다린다.

```text
Simulation App Startup Complete
Welcome to OmniGibson!
Imported scene 0.
```

성공 메시지:

```text
Smoke test complete. Log: /workspace/outputs/logs/r1pro-smoke.log
```

로그 확인:

```bash
tail -n 100 /workspace/outputs/logs/r1pro-smoke.log
```

## 8. 실제로 발생했던 오류와 해결법

### `Required command not found: conda`

원인: RunPod 기본 이미지에 Conda가 없거나 persistent Miniforge가 PATH에 없음.

```bash
ls -l /workspace/environments/miniforge3/bin/conda
source /workspace/VLA_test/scripts/runpod_env.sh
conda --version
```

파일이 없으면 6.3의 Miniforge 설치를 실행한다.

### `Permission denied (publickey)`

원인: 잘못된 개인키, RunPod에 공개키 미등록 또는 오래된 Pod SSH 주소.

```bash
ls -l ~/.ssh/id_ed25519_runpod ~/.ssh/id_ed25519_runpod.pub
chmod 600 ~/.ssh/id_ed25519_runpod
```

RunPod `Connect` 화면의 최신 SSH 사용자 문자열과 `-i ~/.ssh/id_ed25519_runpod`을 사용한다.

### `Your SSH client doesn't support PTY`

```bash
ssh -tt <POD별-SSH-USER>@ssh.runpod.io -i ~/.ssh/id_ed25519_runpod
```

### Vulkan GPU를 찾지 못함

RunPod 환경 변수를 확인한다.

```text
NVIDIA_DRIVER_CAPABILITIES=all
NVIDIA_VISIBLE_DEVICES=all
```

Pod를 재시작한 뒤 다음을 실행한다.

```bash
cd /workspace/VLA_test
bash scripts/00_install_system_deps.sh
vulkaninfo --summary
```

`vulkaninfo`의 `deviceName`에 NVIDIA GPU가 표시돼야 한다.

### `libXt.so.6`, `libGLU.so.1`, `libEGL.so.1` 오류

```bash
cd /workspace/VLA_test
bash scripts/00_install_system_deps.sh
```

시스템 package는 `/workspace`가 아닌 Container에 설치된다. Pod reset/redeploy 이후에는 다시 실행한다.

### base Python으로 OmniGibson을 실행해 module을 찾지 못함

다음처럼 직접 `python`을 호출하지 않는다.

```bash
python some_omnigibson_script.py
```

저장소의 smoke script 또는 environment의 절대 경로를 사용한다.

```bash
bash scripts/02_smoke_behavior.sh
/workspace/environments/conda/envs/behavior/bin/python your_script.py
```

### 설치 중 package conflict warning

Isaac Sim과 OmniGibson이 서로 다른 `pillow`, `websockets`, `packaging` 등의 버전을 요구하는 warning이 있었다. 공식 installer가 완료되고 실제 smoke test가 성공했으므로, warning만 보고 임의로 upgrade/downgrade하지 않는다.

### scene 초기화가 오래 걸림

첫 실행의 cache 생성은 오래 걸린다. CPU/GPU가 활동하고 치명적 traceback이 없다면 중단하지 않는다. 이번 A40 첫 실행은 약 14분 38초가 걸렸다.

## 9. 기존 Volume으로 다시 시작할 때

Pod를 Start하거나 같은 Volume을 새 Pod에 연결한 다음:

```bash
cd /workspace/VLA_test
git pull --ff-only
bash scripts/00_install_system_deps.sh
source scripts/runpod_env.sh
bash scripts/00_preflight_runpod.sh
```

다음 경로가 있으면 BEHAVIOR를 재설치하지 않는다.

```bash
test -x /workspace/environments/conda/envs/behavior/bin/python
test -d /workspace/BEHAVIOR-1K/.git
```

이후 필요한 단계부터 재개한다.

### Volume disk의 GPU 자리가 사라졌을 때

Volume disk는 원래 물리 호스트에 묶인다. 기존 Pod를 Start할 때 GPU capacity 오류가 나면 새 빈 Pod를 직접 만들지 말고 RunPod가 제공하는 `Automatically migrate your Pod data`를 사용한다. 2026-09-02 실제 migration에서는 약 149GB의 `/workspace`를 새 A40 Pod로 복사한 뒤 아래 네 경로를 확인했다.

```bash
test -d /workspace/VLA_test/.git
test -x /workspace/environments/miniforge3/bin/conda
test -x /workspace/environments/conda/envs/behavior/bin/python
test -f /workspace/outputs/logs/r1pro-smoke.log
```

새 컨테이너에는 apt package가 없으므로 migration 후에도 `scripts/00_install_system_deps.sh`를 다시 실행한다. 장기적으로는 독립 Network Volume으로 이전해 GPU 호스트 교체 시 전체 migration을 피한다.

## 10. 작업 종료와 비용 차단

SSH에서 `exit`를 입력하는 것만으로는 GPU 과금이 멈추지 않는다.

1. 실행 중인 프로세스와 로그 저장을 확인한다.
2. SSH에서 `exit`한다.
3. RunPod 콘솔 또는 MCP에서 Pod를 `Stop`한다.
4. 상태가 `EXITED`인지 확인한다.
5. persistent storage는 삭제하지 않는다.

Stop 후:

- GPU 시간 과금 중지
- `/workspace` 데이터 유지
- persistent storage 비용은 계속 발생

## 11. Visual capture 결과와 다음 단계

검증된 캡처 명령:

```bash
cd /workspace/VLA_test
bash scripts/04_capture_r1pro_visuals.sh
```

2026-09-02 실제 출력:

```text
/workspace/outputs/visuals/r1pro_cached_task/
├── scene_r1pro_before.png
├── scene_r1pro_after.png
├── obs__state__external__external_sensor0__rgb.png
├── obs__state__robot_adcuhk__robot_adcuhk_zed_link_Camera_0__rgb.png
├── obs__state__robot_adcuhk__robot_adcuhk_left_realsense_link_Camera_0__rgb.png
├── obs__state__robot_adcuhk__robot_adcuhk_right_realsense_link_Camera_0__rgb.png
├── depth__*.png
├── random_action_episode.mp4
└── capture_metadata.json
```

메타데이터에서 외부·머리·양쪽 손목 RGB/Depth가 모두 128×128로 확인됐고, `state/task/low_dim`은 82차원이었다. MP4에는 60 step이 10fps로 기록됐다. 이후 실행부터 `low_dim` 원본도 `.npy`로 함께 저장한다.

그 다음 순서는 다음과 같다.

```text
제공된 checkpoint baseline 추론
→ 공식 task 하나의 demonstration만 다운로드
→ 데이터 구조 확인
→ 소규모 fine-tuning
→ 같은 조건에서 학습 전후 비교
```

## 12. 관련 파일

- `README.md`: 프로젝트 개요
- `runpod_connect.md`: SSH 접속 및 연결 오류 해결
- `scripts/runpod_env.sh`: 영구 경로와 환경 변수
- `scripts/00_install_system_deps.sh`: EGL/GL/Vulkan 설치
- `scripts/00_preflight_runpod.sh`: GPU, Vulkan, storage, Conda 검사
- `scripts/01_install_behavior.sh`: BEHAVIOR 공식 설치
- `scripts/02_smoke_behavior.sh`: R1Pro cached task smoke test
- `scripts/03_download_task_demos.sh`: 이후 task별 demo chunk 다운로드
- `scripts/04_capture_r1pro_visuals.sh`: 실제 Isaac Sim PNG, Depth, MP4 캡처

공식 기준:

- BEHAVIOR-1K: <https://github.com/StanfordVL/BEHAVIOR-1K/tree/v3.9.2>
- 공식 R1Pro config: <https://github.com/StanfordVL/BEHAVIOR-1K/blob/v3.9.2/OmniGibson/omnigibson/configs/r1pro_behavior.yaml>
- 공식 environment demo: <https://github.com/StanfordVL/BEHAVIOR-1K/blob/v3.9.2/OmniGibson/omnigibson/examples/environments/behavior_env_demo.py>
- 2026 baseline: <https://github.com/StanfordVL/BEHAVIOR-1K/blob/v3.9.2/docs/challenge/baselines.md>
- 공식 demo dataset: <https://huggingface.co/datasets/behavior-1k/2026-challenge-demos>
