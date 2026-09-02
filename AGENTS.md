# VLA_test 에이전트 작업 지침

## 프로젝트 목적

이 저장소의 목적은 2026 BEHAVIOR Challenge의 공식 코드, 공식 데이터와 제공된 사전학습 모델만 사용하여 R1Pro 기반 VLA 파이프라인을 처음부터 끝까지 한 번 재현하는 것이다.

초기 목표는 최고 점수가 아니다. 아래 전체 사이클이 실제로 동작하는지 확인하고, 이후 성능 부족의 원인이 시뮬레이터·관측/제어 연결·모델·데이터 중 어디에 있는지 분리해서 진단할 수 있는 기준선을 만드는 것이 목표다.

```text
시뮬레이터 실행
→ 기본/임의 정책으로 로봇 움직이기
→ 제공된 사전학습 모델로 추론
→ 공식 데이터 구조 확인
→ 작업 하나만 소규모 파인튜닝
→ 동일 조건에서 학습 전후 비교
```

## 현재 상태

- 로컬 저장소와 GitHub `main`이 연결되어 있다.
- RunPod A40 48GB Pod를 사용 중이다.
- 250GB Network Volume이 `/workspace`에 마운트되어 있다.
- Miniforge는 `/workspace/environments/miniforge3`에 설치되어 있다.
- GPU, Network Volume 쓰기 권한, Conda, Git 사전점검이 통과했다.
- 다음 단계는 BEHAVIOR 설치와 R1Pro smoke test다.

현재 Pod의 ID, SSH 사용자 문자열, GPU와 가격은 일시적인 운영 정보다. 코드나 자동화에서 고정값으로 가정하지 말고 RunPod의 현재 상태를 다시 확인한다.

## 실행 순서

순서를 건너뛰지 않는다. 앞 단계의 성공 증거를 남긴 뒤 다음 단계로 진행한다.

1. RunPod 및 `/workspace` preflight
2. BEHAVIOR-1K와 시뮬레이터 자산 설치
3. R1Pro와 task 하나를 headless로 실행
4. RGB, Depth, proprioception, action, 종료 조건 확인
5. 임의 action 또는 공식 기본 정책으로 한 episode 실행 및 로그/영상 저장
6. 제공된 π0.5 체크포인트로 학습 없는 baseline 추론
7. 공식 데모 데이터에서 task 하나의 chunk만 다운로드
8. 관측, action, instruction, episode metadata와 성공 여부 확인
9. demonstration 20~50개 수준의 소규모 부분 파인튜닝
10. 학습에 사용하지 않은 동일 task instance에서 baseline과 fine-tuned 모델 비교

## 환경 분리

하나의 Python 환경에 모든 것을 섞지 않는다.

- Miniforge base: `/workspace/environments/miniforge3`
- BEHAVIOR/OmniGibson 평가 환경: `/workspace/environments/conda/envs/behavior`
- π0.5/OpenPI 학습·서빙 환경: OpenPI 저장소 내부의 별도 `uv` 가상환경

BEHAVIOR 공식 설치는 Conda 환경을 생성한다. 반면 2026 공식 baseline은 정책 학습과 서빙에 `uv`를 사용한다. 두 환경의 CUDA/Python/PyTorch 의존성을 임의로 합치지 않는다.

## 영구 저장 위치

크거나 다시 받기 어려운 파일은 반드시 `/workspace` 아래에 둔다.

```text
/workspace/
├── VLA_test/                     # 이 저장소
├── BEHAVIOR-1K/                  # 공식 시뮬레이터 코드
├── environments/                 # Miniforge, Conda env, 패키지 캐시
├── models/                       # 제공된 사전학습 모델
├── datasets/                     # 공식 task별 데모
├── checkpoints/                  # 우리가 학습한 체크포인트
└── outputs/                      # 로그, 평가 결과, 영상
```

`/root`, `/tmp`, `/opt` 등 Container Disk 위치에 중요한 결과를 두지 않는다. Pod 중지/교체 후 사라질 수 있다.

## 데이터 정책

- 외부 데이터는 첫 공식 end-to-end 사이클이 끝날 때까지 추가하지 않는다.
- 전체 `behavior-1k/2026-challenge-demos`를 다운로드하지 않는다. 전체 크기는 약 3.27TB다.
- 첫 데이터 실험은 `turning_on_radio` 한 task와 해당 chunk로 제한한다.
- 모델 추론에 metadata나 normalization statistics가 필요하면 필요한 최소 파일만 먼저 받는다.
- `setup.sh --dataset`은 시뮬레이터 실행에 필요한 BEHAVIOR scene/object/robot 자산 설치다. Hugging Face의 3.27TB demonstration dataset 다운로드와 구분한다.
- 다운로드 전에 예상 크기와 `/workspace` 잔여 용량을 확인한다.

## 모델 및 학습 정책

- 먼저 제공 checkpoint를 수정 없이 실행해 baseline을 만든다.
- baseline 추론이 실패한 상태에서 파인튜닝으로 넘어가지 않는다.
- 첫 학습은 task 1개, demonstration 20~50개, 500~2,000 step 수준으로 시작한다.
- 48GB 단일 GPU에서는 전체 π0.5 full fine-tuning을 기본값으로 삼지 않는다.
- 첫 실험은 action head, adapter 또는 LoRA 등 부분 파인튜닝을 우선 검토한다.
- 학습 checkpoint와 평가 결과는 실험별 디렉터리에 저장하고 설정과 Git commit을 함께 기록한다.

## 평가 원칙

Baseline과 fine-tuned 모델을 같은 task, 같은 미사용 instance, 같은 timeout과 같은 제어 설정에서 비교한다.

최소 기록 항목:

- 성공률
- task progress
- 평균 episode 길이
- 멈춤 횟수
- 충돌 또는 물체를 놓친 횟수
- 대표 성공/실패 영상
- 실행 설정, checkpoint 경로와 Git commit

## 작업 방식

- 한 번에 한 단계만 실행하고 실제 출력으로 성공 여부를 확인한다.
- 설치와 다운로드는 버전을 고정하고 재실행 가능한 스크립트로 남긴다.
- 장시간 작업은 `/workspace/outputs/logs`에 로그를 남긴다.
- 사용자가 직접 읽고 동의해야 하는 Conda, NVIDIA, 데이터셋 라이선스를 자동 수락하지 않는다.
- 기존 사용자 파일과 변경사항을 덮어쓰거나 삭제하지 않는다.
- 파괴적인 명령, 전체 데이터 다운로드, 고비용 학습, 외부 데이터 추가 전에는 범위와 비용을 명확히 확인한다.
- GPU가 필요하지 않은 문서 작업과 코드 검토는 로컬에서 한다.
- SSH 연결을 종료하는 `exit`는 Pod를 중지하지 않는다. 작업이 끝나면 RunPod에서 Pod 상태와 과금을 확인한다.

## 기본 명령

RunPod 접속 후:

```bash
cd /workspace/VLA_test
git pull --ff-only
bash scripts/00_preflight_runpod.sh
```

BEHAVIOR 설치:

```bash
bash scripts/01_install_behavior.sh
```

R1Pro smoke test:

```bash
bash scripts/02_smoke_behavior.sh
```

task 하나의 공식 demo 다운로드는 앞 단계가 모두 성공한 후에만 실행한다.

```bash
bash scripts/03_download_task_demos.sh 0
```

SSH와 오류 해결은 `runpod_connect.md`를 참고한다.

## 공식 기준

- BEHAVIOR-1K: `v3.9.2`
- Isaac Sim: 공식 BEHAVIOR 설치 스크립트가 지정하는 버전
- BEHAVIOR evaluator Python: `3.11`
- CUDA wheel: `12.8`
- 기본 로봇: `R1Pro`
- 첫 task: `turning_on_radio`
- 공식 baseline 문서: <https://github.com/StanfordVL/BEHAVIOR-1K/blob/v3.9.2/docs/challenge/baselines.md>
- 공식 demo dataset: <https://huggingface.co/datasets/behavior-1k/2026-challenge-demos>

공식 Challenge 문서와 태그가 바뀔 수 있으므로 평가 직전에는 현재 공식 권장 버전을 다시 확인한다. 검증 없이 자동으로 최신 버전으로 올리지는 않는다.
