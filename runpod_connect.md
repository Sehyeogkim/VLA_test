# RunPod 접속 가이드

이 문서는 로컬 Mac 터미널에서 RunPod Pod에 SSH로 접속하고, VLA 작업을 이어서 시작하기 위한 체크리스트다.

## 핵심 원칙

- RunPod 콘솔의 Pod `Connect` 탭에 표시되는 SSH 명령을 기준으로 한다.
- Pod를 새로 생성하면 Pod ID와 SSH 사용자 문자열이 바뀔 수 있다.
- 개인키와 API 키는 절대로 GitHub에 커밋하지 않는다.
- 코드, 환경, 데이터, 체크포인트, 출력은 모두 영구 Network Volume인 `/workspace` 아래에 둔다.
- `exit`는 SSH 접속만 종료한다. GPU 과금을 멈추려면 RunPod 콘솔에서 Pod를 `Stop`해야 한다.
- Pod를 멈춰도 Network Volume 저장 비용은 계속 발생한다. Volume을 삭제하면 그 안의 파일도 삭제된다.

## 현재 사용하는 SSH 키

로컬 Mac의 개인키 경로:

```text
~/.ssh/id_ed25519_runpod
```

키 파일이 있는지 확인한다.

```bash
ls -l ~/.ssh/id_ed25519_runpod ~/.ssh/id_ed25519_runpod.pub
chmod 600 ~/.ssh/id_ed25519_runpod
```

`id_ed25519_runpod`은 개인키이므로 GitHub, Notion, 채팅 등에 내용을 붙여 넣지 않는다. RunPod 계정에는 `.pub` 파일의 공개키만 등록한다.

## SSH 접속

일반 형식:

```bash
ssh -t <RUNPOD_SSH_USER>@ssh.runpod.io -i ~/.ssh/id_ed25519_runpod
```

2026-09-02에 실제로 성공한 A40 Pod 접속 예시:

```bash
ssh -t 1l1snvbh5l86jq-64411b54@ssh.runpod.io -i ~/.ssh/id_ed25519_runpod
```

이 문자열은 현재 Pod용 예시다. 새 Pod에서는 콘솔의 `Connect` 탭에서 새 명령을 복사한다. 자동화 도구가 `Your SSH client doesn't support PTY`를 출력하면 `-t` 대신 `-tt`를 사용한다.

첫 접속 시 서버 fingerprint 질문이 나오면 RunPod의 `ssh.runpod.io` 호스트인지 확인한 후 `yes`를 입력한다.

## 접속 직후 실행

```bash
cd /workspace/VLA_test
git pull --ff-only
bash scripts/00_install_system_deps.sh
bash scripts/00_preflight_runpod.sh
```

`00_install_system_deps.sh`는 Isaac Sim의 headless Vulkan 실행에 필요한 EGL/GL/GLU/Xt 패키지를 설치한다. 이 패키지는 `/workspace`가 아니라 Pod 컨테이너에 설치되므로, **Pod를 새로 만들거나 컨테이너를 reset/redeploy한 뒤에는 다시 실행**한다. 스크립트는 여러 번 실행해도 안전하다.

RunPod Pod 환경 변수에는 다음 값이 필요하다.

```text
NVIDIA_DRIVER_CAPABILITIES=all
NVIDIA_VISIBLE_DEVICES=all
```

RunPod 런타임이 `NVIDIA_VISIBLE_DEVICES`를 내부적으로 바꾸더라도 `nvidia-smi`와 `vulkaninfo --summary`에서 실제 GPU가 보이면 정상이다.

정상이라면 다음 항목이 출력된다.

- GPU 이름과 VRAM
- Vulkan에서 인식한 GPU
- `/workspace` Network Volume 마운트 정보
- Python, Conda, Git 버전
- `Preflight passed. /workspace is writable.`

현재 Miniforge는 아래 영구 경로에 설치되어 있다.

```text
/workspace/environments/miniforge3
```

저장소의 `scripts/runpod_env.sh`가 위 경로를 자동으로 `PATH`에 추가하므로, 새 SSH 세션에서도 프로젝트 스크립트가 Conda를 찾는다.

## BEHAVIOR 설치 재개

Preflight가 통과한 다음에만 실행한다.

```bash
cd /workspace/VLA_test
bash scripts/01_install_behavior.sh
```

공식 라이선스 동의 질문은 직접 읽고 응답한다. 전체 데모 데이터셋은 아직 다운로드하지 않는다.

## R1Pro smoke test

설치가 끝난 뒤 다음 명령으로 공식 cached BEHAVIOR 예제를 headless로 100 step 실행한다.

```bash
cd /workspace/VLA_test
bash scripts/02_smoke_behavior.sh
```

첫 실행은 shader, collision, TorchInductor 캐시 생성 때문에 10~20분 이상 걸릴 수 있다. `Imported scene 0`, `Welcome to OmniGibson!` 같은 로그가 보이고 CPU/GPU가 활동 중이면 기다린다. 성공 시 다음 메시지가 출력된다.

```text
Smoke test complete. Log: /workspace/outputs/logs/r1pro-smoke.log
```

2026-09-02 A40 검증에서는 Isaac Sim 5.1이 Vulkan으로 A40을 인식했고 R1Pro 100-step smoke test가 약 14분 38초에 정상 종료됐다.

## 자주 발생하는 오류

### `Identity file ... not accessible`

명령에 적은 개인키 경로가 실제 파일명과 다르다는 뜻이다.

```bash
ls -la ~/.ssh
```

현재 프로젝트에서는 `~/.ssh/id_ed25519_runpod`을 사용한다.

### `Permission denied (publickey)`

다음을 순서대로 확인한다.

1. RunPod 콘솔 `Connect` 탭의 SSH 사용자 문자열을 정확히 복사했는지 확인한다.
2. `-i ~/.ssh/id_ed25519_runpod`을 사용했는지 확인한다.
3. `~/.ssh/id_ed25519_runpod.pub`의 공개키가 RunPod 계정에 등록되어 있는지 확인한다.
4. 실행 중인 Pod를 만든 뒤 공개키를 등록했다면 Pod를 재시작하고 다시 접속한다.

### `Your SSH client doesn't support PTY`

```bash
ssh -tt <RUNPOD_SSH_USER>@ssh.runpod.io -i ~/.ssh/id_ed25519_runpod
```

### `cd: ... No such file or directory`

Linux 경로는 대소문자를 구분한다. 정확한 경로는 다음과 같다.

```bash
cd /workspace/VLA_test
```

### `Required command not found: conda`

먼저 영구 설치가 남아 있는지 확인한다.

```bash
ls -l /workspace/environments/miniforge3/bin/conda
source /workspace/VLA_test/scripts/runpod_env.sh
conda --version
```

파일 자체가 없다면 새로운 Network Volume이거나 설치되지 않은 상태다. Miniforge를 `/workspace/environments/miniforge3`에 다시 설치한 뒤 preflight를 실행한다.

## 작업 종료

Pod 안에서:

```bash
exit
```

그다음 RunPod 콘솔에서 반드시 Pod를 `Stop`하고 상태가 멈췄는지 확인한다. `/workspace`의 Network Volume은 유지되므로 저장한 코드, 환경, 데이터와 출력은 다음 Pod에서도 다시 연결해 사용할 수 있다.
