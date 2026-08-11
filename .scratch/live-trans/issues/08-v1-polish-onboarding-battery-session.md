# 08 — v1 마감: 온보딩·절전·세션 유지

**What to build:** v1 출시 수준으로 매끄럽게 마무리한다. 첫 실행 시 화면 녹화 권한 필요성과 동작 방식을 안내하고, 변화 감지 기반 절전 파라미터를 다듬으며, 앱을 닫아도 번역 세션과 PiP가 유지되는 것을 확인한다. v1 완료 기준(브라우징 중 화면 속 텍스트 번역 + 웹툰/만화 제자리 번역)을 만족하는 상태를 검증한다.

**Blocked by:** 05 — 캡션 품질·조작, 07 — 제자리 번역 품질 트랙

**Status:** ready-for-agent

- [ ] 첫 실행에 권한 안내 온보딩이 표시되고 흐름이 끊기지 않는다
- [ ] 변화 감지 기반 절전이 동작해 대기 화면에서 불필요한 캡처가 멈춘다
- [ ] 앱을 닫아도 PiP와 번역 세션이 유지되고, off/PiP 닫기로 종료된다
- [ ] v1 완료 기준 시나리오(웹 텍스트 번역 → 웹툰 대사 제자리 번역 → 토글 off)가 종단간 통과한다

## Comments

- 2026-08-11 (agent): **코어 구현 완료** (ADR-0003, Windows TDD 대상).
  - `Sources/LiveTransCore/`:
    - `OnboardingFlow` — 첫 실행 온보딩 상태 머신(`notStarted` → `permissionRequested` → `completed`) + `OnboardingPersisting`. 완료 상태는 재시작 후 유지.
    - `CaptureStandbyPolicy` — 대기 화면 절전. 같은 화면(핑거프린트)이 idle 기준(`standbyAfterIdleInterval`, 기본 10s)을 넘으면 `CaptureActivity.standby`로 전환, 화면이 바뀌면 `active`로 복귀. 셸이 이 신호로 캡처 루프를 멈출 수 있게 함.
    - `TranslationSessionCoordinator` — 온보딩 + 세션 + 캡처 활동 조율. 첫 실행 토글 시 온보딩을 먼저 띄우고(세션 미시작), 완료 시 대기 중이던 세션 시작이 이어짐("흐름이 끊기지 않음"). 세션 active 중에만 캡처 활동을 발행하고, 종료/대기 시 `standby`로 멈춤. `observeScreen(fingerprint:at:)`가 캡처 활동 결정을 셸에 전달.
  - 테스트 신규 20건: `OnboardingFlowTests` 5건, `CaptureStandbyPolicyTests` 5건, `TranslationSessionCoordinatorTests` 7건, `V1CompletionScenarioTests` 3건(온보딩→웹 캡션→웹툰 제자리→off 종단간, 캐스케이드 폴백 이벤트 전달, 세션 종료 시 캡처 standby). 누적 80건.
  - 검증은 `swift test` (툴체인 설치 후).
  - **미구현(코어 범위 밖, iOS 셸)**: 온보딩 UI 화면, 화면 녹화 권한 요청, ReplayKit 캡처 루프에 `CaptureStandbyPolicy` 연결(standby 시 프레임 획득 중단), PiP 유지/닫기 처리, 툴체인 설치 가이드(`docs/dev-environment-windows.md`) 실행.