# 01 — 앱 스캐폴드 + 번역 세션 토글

**What to build:** live-trans 앱의 기본 골격과 "번역 세션" 시작/종료를 제어하는 토글 UI를 만든다. 사용자가 앱을 열고 토글을 on/off 할 수 있고, 토글 상태가 세션 상태로 반영된다.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] 앱을 실행하면 번역 토글 화면이 보인다
- [ ] 토글을 on하면 번역 세션이 "시작됨" 상태가 되고, off하면 "종료됨" 상태가 된다
- [ ] 번역 세션이 active일 때 앱 화면에 현재 상태가 표시된다
- [ ] 토글 상태가 앱 재시작 후에도 유지된다

## Comments

- 2026-08-11 (agent): **코어 구현 완료** (Windows TDD로 로직 검증).
  - `Sources/LiveTransCore/`: `TranslationSession` 상태 머신(ended/starting/active/paused/stopping), `toggle/start/stop/pause/resume`, `TranslationSessionState`, `TranslationSessionPersisting` + `onStateChange` 이벤트.
  - 재시작 유지: `TranslationSession(persistence:)`가 생성 시 persist 된 상태를 load.
  - `@testable` 테스트 8건(상태 전이, 토글, 재시작 유지, pause/resume, 옵저버 통지).
  - 검증은 `swift test` (툴체인 설치 후, `docs/dev-environment-windows.md`).
  - **UI(토글 화면)는 iOS 셸** — ADR-0003에 따라 macOS CI 스캐폴드 시점에 구성.