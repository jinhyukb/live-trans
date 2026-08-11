# Windows 개발 환경 — Swift 툴체인 설치

ADR-0003에 따라 LiveTransCore(순수 Swift)는 Windows 로컬에서 TDD로 개발한다. iOS 셸은 GitHub Actions macOS 러너에서 빌드한다.

## 공식 요구사항 (swift.org)

Visual Studio 2022(Community 이상)에 Windows 11 SDK 10.0.22621 과 MSVC x64/ARM64 빌드 도구가 설치되어 있어야 한다.

현재 상태(설치 확인 명령):

```powershell
# VS 2022 설치 여부
Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022"
# 설치된 MSVC / Windows SDK 버전
Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC"
Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\Include"
```

필요한 컴포넌트(Windows11SDK.22621, VC.Tools.x86.x64, VC.Tools.ARM64)가 없으면 **Visual Studio Installer**를 열고 해당 워크로드를 추가한다. 현재 SDK가 10.0.22000 이므로 Swift 공식 문구(22621)보다 낮은데, 보통 22000+ 이면 충분하나 실패 시 VS Installer로 22621 SDK를 추가한다.

## Swift 설치

winget 가 안 되므로(없음) 공식 매뉴얼 설치기 사용:

1. https://www.swift.org/install/windows/ → **Manual Installation** → `swift-6.3.3-RELEASE-windows10.exe` (x86_64) 다운로드
2. 실행해 설치 (PATH에 자동 등록됨)
3. 새 터미널에서 확인:

```powershell
swift --version
```

## 패키지 테스트

```powershell
cd D:\workspace\live-trans
swift test
```

## VS Code 편집

`swiftlang.swift-vscode` 확장을 설치하면 SPM 빌드·테스트, 디버깅(LLDB), Test Explorer를 사용할 수 있다.

## iOS 셸 빌드 (Windows 불가)

ReplayKit/SwiftUI/PiP 셸은 Xcode가 필요한 macOS 전용이다. 워크플로는 `.github/workflows/ios-build.yml`에서 GitHub Actions macOS 러너로 빌드해 unsigned `.ipa` 아티팩트를 만든다.

실기기 검증은 Mac 없이 두 경로 중 하나로 한다:
- **무료(비용 0)**: `docs/sideload-free-account.md` — 무료 Apple ID로 Sideloadly/AltStore 사이드로드. 7일 만료.
- **유료**: App Store Connect API → TestFlight. 서명 인증서·프로비저닝(비밀)을 워크플로우에 추가해야 한다.

ADR-0003에 따라 먼저 무료 사이드로드로 검증하고, 스파이크(티켓 02) 통과 후에 TestFlight 전환을 검토한다.