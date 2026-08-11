# 05 — 캡션 품질·조작

**What to build:** 플로팅 캡션의 결과를 깨끗하게 다듬고 조작을 추가한다. OCR 필터링(1~2글자 단독, 숫자/기호만, 이미 한국어, 동일 문자열 반복 제외)으로 노이즈를 줄이고, PiP 탭 시 일시정지/재개, 소스 언어 수동 지정, 감지 실패 시 폴백을 지원한다.

**Blocked by:** 04 — 화면 속 텍스트 → 플로팅 캡션 번역

**Status:** ready-for-agent

- [ ] 필터링 규칙(1~2글자, 숫자/기호, 한국어, 반복 문자열)이 캡션 노이즈를 제거한다
- [ ] PiP 창을 탭하면 캡션이 일시정지되고 다시 탭하면 재개된다
- [ ] 소스 언어 감지 실패 시 사용자가 캡션에서 언어를 수동 지정할 수 있다
- [ ] 캡션 표시 시점(스크롤 중갱신)이 눈에 띄게 늦지 않고, 배터리 부담이 개선 전 대비 커지지 않는다

## Comments

- 2026-08-11 (agent): **코어 구현 완료** (ADR-0003, Windows TDD 대상).
  - `Sources/LiveTransCore/`:
    - `ScreenTextFilter` — OCR 노이즈 필터: 최소 글자 수(1~2글자 단독 제거), 숫자·기호만, 이미 한국어(`HeuristicSourceLanguageDetector` 재사용), 대소문자 무시 동일 문자열 반복 제거. 각 규칙 on/off 가능.
    - `TranslationPipeline`을 class로 전환 + 확장: `filter` 내장, `isPaused`/`pause()`/`resume()`(PiP 탭 일시정지), `manualSourceLanguage` 수동 지정, 감지 실패 시 `CaptionState.needsSourceSelection` 발행. `CaptionState`에 `needsSourceSelection` 추가.
    - 배터리: 필터로 처리량 감소 + 기존 `ChangeDetector` 스로틀·hold·창구간 상한 유지.
  - 테스트 신규: `ScreenTextFilterTests` 7건, pipeline 3건 추가(필터 연동·일시정지·수동 언어·감지 실패).
  - 검증은 `swift test` (툴체인 설치 후).
  - **미구현(코어 범위 밖, iOS 셸)**: PiP 탭 이벤트 → `pause()/resume()` 연결, 수동 언어 선택 UI, "준비 중" 표시 UI.