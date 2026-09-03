# VLA_test 프로젝트 컨텍스트

작업을 시작하기 전에 루트의 `AGENTS.md`를 읽고 그 지침을 따른다. 이 파일은 Claude Code를 위한 빠른 진입점이며, 상세 규칙의 기준 문서는 `AGENTS.md`다.

## 목적

2026 BEHAVIOR Challenge에서 공식 코드, 공식 데이터와 제공된 사전학습 모델만으로 R1Pro VLA 파이프라인을 끝까지 한 번 재현한다. 초기 목표는 성능 경쟁이 아니라 시뮬레이터, 관측, action, baseline 추론, 데이터 로딩, 소규모 학습과 평가가 연결되는 기준선을 만드는 것이다.

## 반드시 지킬 순서

```text
RunPod preflight
→ BEHAVIOR 설치
→ R1Pro task 1개 smoke test
→ RGB/Depth/proprioception/action 확인
→ 제공 checkpoint baseline 추론
→ 공식 task 1개 데이터 확인
→ 소규모 부분 파인튜닝
→ 같은 조건에서 학습 전후 비교
```

## 핵심 제약

- 모든 큰 파일과 결과는 `/workspace` 아래에 저장한다.
- 전체 3.27TB demonstration dataset을 다운로드하지 않는다.
- 첫 공식 end-to-end 사이클 전에는 외부 데이터를 추가하지 않는다.
- baseline 추론 전에 학습을 시작하지 않는다.
- BEHAVIOR/OmniGibson은 전용 Conda 환경을 사용한다.
- π0.5/OpenPI 정책 학습·서빙은 공식 절차대로 별도 `uv` 환경을 사용한다.
- 라이선스 동의를 자동화하지 않는다.
- GPU가 필요 없는 작업 중에는 Pod가 계속 과금 중인지 확인한다.

## 현재 상태와 다음 단계

RunPod A40 48GB에서 BEHAVIOR-1K 설치, R1Pro cached-task smoke test, 실제 viewer 및 카메라별 RGB/Depth와 random-action MP4 캡처까지 완료되었다. 최초 `/workspace`는 독립 Network Volume이 아니라 250GB Volume disk였으므로, 호스트 변경에는 migration이 필요하다. 현재 Pod는 `EXITED`이며 다음 단계는 제공된 checkpoint의 baseline 추론 연결이다.

```bash
cd /workspace/VLA_test
git pull --ff-only
bash scripts/00_install_system_deps.sh
bash scripts/00_preflight_runpod.sh
```

접속 정보와 문제 해결은 `runpod_connect.md`, 상세 목적·데이터·학습·평가 정책은 `AGENTS.md`를 참고한다.
