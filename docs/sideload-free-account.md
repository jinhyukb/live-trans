# Mac 없이 iPhone에 설치하기 — 무료 Apple ID 사이드로드

ADR-0003의 무료 경로. GitHub Actions macOS 러너가 unsigned `.ipa`를 만들면, Windows의 AltStore(Sideloadly)가 무료 Apple ID로 서명해 iPhone에 설치한다. 유료 계정/TestFlight 없이 실기기 검증을 시작하는 방법.

## 전제

- iPhone (iOS 18 이상), USB 케이블 또는 같은 Wi-Fi
- 무료 Apple ID (2단계 인증 가능해야 함)
- Windows에 AltServer(AltStore용) 또는 Sideloadly — 둘 중 하나면 충분
- GitHub Actions `ios-build.yml`이 만든 `.ipa` 아티팩트

## 1. IPA 확보

`ios-build` 워크플로우가 성공하면 아티팩트 `live-trans-ipa`에 `ios/live-trans.ipa`가 올라온다. 다운로드해서 Windows에 저장한다.

## 2. 서명 도구 선택

| 도구 | 서명 | 만료 | 특징 |
|------|------|------|------|
| **AltStore** | Apple ID, 자동 재서명 | 7일 | 백그라운드에서 주기적으로 재서명 가능 |
| **Sideloadly** | Apple ID, 수동 | 7일 | 브로드캐스트 익스텐션 포함 주입에 유리 |

v1은 **Sideloadly** 우선. ReplayKit 브로드캐스트 익스텐션은 앱 포함 `PlugIns/`에 들어 있어야 하고, Sideloadly가 IPA 내 익스텐션까지 함께 서명해 설치해 준다.

## 3. Sideloadly로 설치

1. 서명된 앱을 실행하려면 iPhone에서 **설정 > 일반 > 개발자 모드(Developer Mode)** 를 켠다. iOS 16+에서는 사이드로드한 앱도 개발자 모드가 필요하다.
2. Mac 없이 Windows에서:
   - Sideloadly 실행 → iPhone을 USB로 연결
   - `.ipa` 선택 → Apple ID 입력 → Install
3. 설치 완료 후 앱이 홈 화면에 나타난다.

## 4. 브로드캐스트 익스텐션 동작 확인

앱 안의 `RPSystemBroadcastPicker`로 화면 공유를 시작하면 ReplayKit이 브로드캐스트 익스텐션을 불러온다. 이게 되지 않으면:
- 앱과 익스텐션의 Bundle ID가 한 Apple ID로 함께 서명되었는지 확인
- 익스텐션의 `NSExtensionPrincipalClass`와 `RPBroadcastProcessModeSampleBuffer`가 Info.plist에 들어 있는지 확인 (project.yml에서 생성됨)

## 7일 만료 대응

무료 Apple ID 서명은 7일 후 만료되므로 재설치가 필요하다. AltStore는 Wi-Fi로 주기적 재서명이 되고, Sideloadly는 수동으로 다시 인스톨해야 한다. 개발 루프 동안 만료 대비가 필요하면 AltStore를 쓰는 것이 낫다.

## 플로우 요약

```
Windows TDD (LiveTransCore)
   ↓ swift test
GitHub Actions macOS 러너
   ↓ xcodegen + xcodebuild
unsigned .ipa  (아티팩트)
   ↓ Sideloadly (무료 Apple ID 서명)
iPhone 설치 → 화면 공유(ReplayKit) → 루프백 → PiP 검증
```

이 경로의 검증 결과는 `.scratch/live-trans/issues/02-capture-overlay-spike.md` 하단 `## Answer`에 기록한다.