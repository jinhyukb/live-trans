# 04 — 화면 속 텍스트 → 플로팅 캡션 번역

**What to build:** 첫 세로 슬라이스. 캡처 프레임에서 화면 속 텍스트를 OCR로 추출해 소스 언어를 자동 감지한 뒤 온디바이스로 번역하고, 결과를 PiP 플로팅 캡션에 실시간으로 표시한다. 사용자가 Safari에서 영어/일본어 페이지를 스크롤하면 번역문이 캡션 창에서 따라온다.

**Blocked by:** 03 — 캡처 세션 가동/중지 연결

**Status:** ready-for-agent

- [ ] Safari 중심으로 화면 속 텍스트가 감지·번역되어 플로팅 캡션에 나타난다
- [ ] 스크롤로 화면이 바뀌면 캡션 내용이 새 번역으로 갱신된다 (변화 감지 기반)
- [ ] 영어→한국어, 일본어→한국어가 온디바이스에서 동작하고 소스 언어는 자동 감지된다
- [ ] 번역 중에는 "준비 중" 상태가 캡션에 표시된다

## Comments

- 2026-08-11 (agent): **코어 구현 완료** (ADR-0003, Windows TDD 대상).
  - `Sources/LiveTransCore/`:
    - `ChangeDetector` — 변화 감지(같은 화면 hold, minimumInterval 스로틀, 창구간 최대 처리 수)로 배터리 절약. 변화 없으면 캡션 재처리 안 함.
    - `HeuristicSourceLanguageDetector` — 영문/일본어(가나)/한국어 문자 기반 자동 감지, OCR languageHint 우선, 지배 언어 선택.
    - `TranslationPipeline<Payload>` — OCR·번역을 클로저로 주입받는 오케스트레이션. 변화 감지 통과 시 `preparing` → `ready([TranslatedTextBlock])` / `failed` 상태를 `onCaptionStateChange`로 발행. 빈 텍스트 블록 필터 포함.
    - 도메인 모델: `CapturedScreen`, `ScreenTextBlock`, `NormalizedRect`, `Language`, `CaptionState`.
  - 테스트 15건: `ChangeDetectorTests`, `HeuristicSourceLanguageDetectorTests`, `TranslationPipelineTests`.
  - 검증은 `swift test` (툴체인 설치 후).
  - **미구현(코어 범위 밖, iOS 셸)**: 실제 Vision OCR, 온디바이스 번역 엔진, PiP 캡션 UI. OCR 언어 힌트/온디바이스 엔진은 셸이 `HeuristicSourceLanguageDetector`·`TranslationPipeline` 클로저로 연결.