# 06 — 이미지 속 텍스트 자동 제자리 번역

**What to build:** 이미지 속 텍스트(만화/웹툰 대사)를 감지하면 전체 화면 스냅샷 위에 원문 위치에 맞춰 번역문을 덧씌우는 제자리 번역으로 자동 전환한다. 스냅샷은 고정이며, 탭/스와이프로 닫으면 원래 앱 흐름으로 복귀한다.

**Blocked by:** 04 — 화면 속 텍스트 → 플로팅 캡션 번역

**Status:** ready-for-agent

- [ ] 웹툰/만화 페이지를 보면 감지된 대사가 원문 위치에 제자리 번역된 전체 화면이 뜬다
- [ ] 어떤 조건에서도 번역을 멈추지 않고, 이미지 속 텍스트가 있으면 자동으로 전환된다
- [ ] 탭 또는 스와이프로 닫으면 원래 앱 화면으로 즉시 복귀한다
- [ ] 제자리 번역 결과는 v1 기준(원문 위 오버레이)으로 충분히 읽기 좋다

## Comments

- 2026-08-11 (agent): **코어 구현 완료** (ADR-0003, Windows TDD 대상).
  - `Sources/LiveTransCore/`:
    - `ScreenTextBlock.kind` 추가 (`onScreen`/`embedded`) — 화면 속 vs 이미지 속 텍스트 구분.
    - `InPlaceModeDecider` — 이미지 속 텍스트 비중/개수 임계값으로 제자리 번역 전환 여부 판정.
    - `InPlaceLayoutEngine` — 번역문을 원문 위치(`sourceRect`)에 배치. 긴 번역문은 폰트 스케일 축소로 원문 영역에 맞추고, 겹치는 블록은 아래로 밀어낸다. 정규화 좌표 기반(순수 수학, UI 비의존).
    - 모델: `InPlaceTextPlacement`, `InPlaceLayout`.
  - 테스트 신규: `InPlaceModeDeciderTests` 5건, `InPlaceLayoutEngineTests` 6건.
  - 검증은 `swift test` (툴체인 설치 후).
  - **미구현(코어 범위 밖, iOS 셸)**: 전체 화면 스냅샷 고정, 제자리 렌더링 뷰, 탭/스와이프 닫기, 파이프라인→`InPlaceModeDecider`→`InPlaceLayoutEngine` 연결.