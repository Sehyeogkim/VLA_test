# VLA_test

BEHAVIOR-1K 2026 환경을 RunPod에서 재현하기 위한 최소 실행 저장소입니다.

## 지금은 데이터셋부터 받지 않습니다

첫 순서는 아래와 같습니다.

1. 로컬에서 설치·검증 스크립트를 준비하고 GitHub에 반영
2. RunPod A6000 Pod과 250GB Network Volume 생성
3. `/workspace` 마운트 및 GPU 사전 점검
4. BEHAVIOR-1K `v3.9.2`와 필수 시뮬레이터 자산 설치
5. R1Pro 공식 random-action smoke test
6. 제공된 사전학습 체크포인트 추론
7. 그 다음에만 `turning_on_radio` 한 작업의 데모를 다운로드

전체 2026 데모 데이터셋은 3TB가 넘으므로 250GB Volume에 전체를 받으면 안 됩니다. 학습 데이터는 smoke test와 사전학습 모델 추론이 성공한 뒤 작업별 chunk만 받습니다.

## RunPod에서 실행

Pod 생성 후 터미널에서:

```bash
cd /workspace
git clone https://github.com/Sehyeogkim/VLA_test.git
cd VLA_test

bash scripts/00_preflight_runpod.sh
bash scripts/01_install_behavior.sh
bash scripts/02_smoke_behavior.sh
```

설치 스크립트는 Conda, NVIDIA Isaac Sim, BEHAVIOR Dataset 약관을 터미널에 표시합니다. 내용을 확인하고 사용자가 직접 동의해야 설치가 계속됩니다.

한 작업의 학습 데이터 다운로드는 나중에 실행합니다.

```bash
bash scripts/03_download_task_demos.sh 0
```

기본값 `0`은 첫 번째 task chunk입니다. 전체 데이터셋을 다운로드하는 명령은 의도적으로 제공하지 않습니다.

## 영속 저장 위치

중요한 파일은 전부 `/workspace` 아래에 둡니다.

```text
/workspace/
├── VLA_test/
├── BEHAVIOR-1K/
├── datasets/
├── checkpoints/
├── models/
├── environments/
└── outputs/
```

`/workspace` 밖의 Container Disk 파일은 Pod 수명과 함께 사라질 수 있습니다.

## 고정한 공식 버전

- BEHAVIOR-1K: `v3.9.2`
- Isaac Sim: BEHAVIOR 설치 스크립트가 지정하는 `5.1.0`
- Python: `3.11`
- CUDA wheel: `12.8`
- 첫 로봇: `R1Pro`

버전은 재현성을 위해 자동으로 최신화하지 않습니다.

