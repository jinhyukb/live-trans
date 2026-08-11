# 07 — 제자리 번역 품질 트랙 (Papago 캐스케이드)

**What to build:** 제자리 번역에서 온디바이스 외에 Naver Papago 무료 API(일 10,000자)를 보강 엔진으로 사용하는 캐스케이드를 구현한다(ADR-0001). 네트워크가 가능하고 쿼터가 남아 있으면 Papago 결과로, 쿼터 소진/실패 시 온디바이스 결과로 폴백된다.

**Blocked by:** 06 — 이미지 속 텍스트 자동 제자리 번역

**Status:** ready-for-agent

- [ ] Papago 무료 API로 일본어/영어 → 한국어 제자리 번역이 동작한다
- [ ] 하루 쿼터(10,000자) 소진 시 자동으로 온디바이스 결과로 폴백하고 사용자에게 알린다
- [ ] 네트워크 실패·오류 시 캡션이 막히지 않고 온디바이스 결과를 표시한다
- [ ] 원문 위치 렌더링이 Papago 결과에서도 유지된다

## Comments

- 2026-08-11 (agent): **코어 구현 완료** (ADR-0003, Windows TDD 대상).
  - `Sources/LiveTransCore/`:
    - `TranslationQuota` + `TranslationQuotaTracker` — 일 10,000자 쿼터 추적. 날짜(Calendar) 단위 롤오버, 한도 클램프, 잔여량/소진 판정.
    - `CascadeTranslator` — 온디바이스 기본 + Papago 보강 캐스케이드. 쿼터 잔여 + 네트워크 가능 시 Papago 사용(사용 후 쿼터 소비), 쿼터 소진/네트워크 불가/Papago 오류 시 온디바이스로 폴백하고 `CascadeEvent`(`fellBackToOnDevice(reason:)`)로 사용자 알림용 이벤트 발행. 쿼터는 Papago 성공 시에만 소비(오류 시 미소비).
    - `PapagoTranslating` 프로토콜 — 실제 Papago HTTP 클라이언트는 iOS 셸에서 구현(네트워크 의존), 코어는 스텁으로 주입.
    - `Language.papagoSourceCode` — en/ja/ko 코드 매핑.
    - `TranslationPipeline` 연동 — `.embedded` 블록은 `cascadeTranslator` 경유, 전체가 제자리 모드면 `CaptionState.inPlaceReady(InPlaceLayout)` 발행(06의 파이프라인 연결 일부 완료). 캐스케이드 이벤트는 `onCascadeEvent`로 전달.
  - 테스트 신규: `TranslationQuotaTrackerTests` 5건, `CascadeTranslatorTests` 6건, `TranslationPipelineCascadeTests` 3건(캐스케이드 경유 / 제자리 레이아웃 / 폴백 이벤트 전달). 누적 60건.
  - 검증은 `swift test` (툴체인 설치 후).
  - **미구현(코어 범위 밖, iOS 셸)**: 실제 Papago HTTP 클라이언트(NCP 인증 헤더), 쿼터 영속화(사용자 기본값), 폴백 배지 UI.