# 개발 환경 — Windows 전용, 클라우드 macOS CI에서 iOS 빌드

## 결정

개발자는 Mac 없이 Windows에서만 개발한다. iOS SDK(ReplayKit, AVKit, SwiftUI)는 Xcode를 통해서만 배포되므로, 공식 Swift Windows 툴체인으로 iOS 타깃을 빌드하는 것은 불가능하다(툴체인은 Windows 타깃 전용). 따라서 코드를 두 계층으로 분리하고 각 계층을 서로 다른 환경에서 빌드·테스트한다.

1. **LiveTransCore (Swift Package, Apple 프레임워크 미사용)**
   - 번역 파이프라인 오케스트레이션 전부: 번역 세션 상태 머신, OCR 필터링, 소스 언어 자동 감지, 번역 엔진 캐스케이드, 변화 감지(절전), 캡션/제자리 번역 배치 조립.
   - `import UIKit` / `ReplayKit` / `AVKit` / `SwiftUI` 금지 — 순수 언어 + Foundation만.
   - Windows Swift 툴체인(공식, SPM 지원)으로 `swift test` 실행. XCTest/Swift Testing 모두 Windows 공식 지원.
   - 로컬 개발 루프: Windows에서 TDD.

2. **iOS 셸 (App + Broadcast Extension)**
   - SwiftUI 뷰, ReplayKit 브로드캐스트 익스텐션, 로컬 루프백 서버, PiP 오버레이, Papago 네트워크 호출.
   - GitHub Actions macOS 러너에서 빌드·서명, App Store Connect API로 TestFlight 업로드.
   - 실기기 검증은 TestFlight(내부 테스터)로 수행.
   - iOS 셸은 LiveTransCore에만 의존한다(역방향 의존 금지).

## 이유

- 무료 하드 제약(ADR-0001)과 iOS 네이티브 캡처 경로(ADR-0002)를 유지하면서 Mac 없이 개발을 가능하게 한다.
- 비즈니스 로직의 대부분(티켓 01, 04~07의 오케스트레이션)은 순수 Swift라 Windows에서 빠른 피드백으로 개발 가능.
- iOS 전용 검증(티켓 02 스파이크, PiP 조작, 회전/키보드 스트림 유지)은 실기기가 필요한 고유 작업이므로 CI→TestFlight 경로에 맡긴다.

## 대안 검토

- **Swift→iOS 크로스 컴파일**(EdgeCompiler 류, iOS SDK 스텁 기반): 비공식이며 라이선스 회색지대, 프로덕션 부적합. 기각.
- **macOS VM / 해킨토시**: Apple EULA 위반, 불안정. 기각.
- **macOS 클라우드 대여**(MacStadium/MacinCloud): 유료 월 구독. GitHub Actions 무료 티어 대비 추가 비용이라 채택하지 않고, 대용량 빌드가 필요한 경우로 열어둔다.
- **크로스 플랫폼 프레임워크**(Flutter/React Native): ADR-0002의 ReplayKit 우회 기법이 iOS 네이티브를 전제. 기각.

## 영향

- 모든 오케스트레이션 로직 티켓은 Windows에서 `swift test`로 완료 기준을 검증한다.
- 티켓 02(캡처·오버레이 스파이크)는 실기기+CI 검증이 필요한 첫 관문이다. CI 파이프라인은 이 티켓 이전에 구성한다.
- 오픈소스 Swift Windows 툴체인 설치는 `docs/agents/` 또는 repo 루트에 스캐폴드 가이드로 문서화한다.
