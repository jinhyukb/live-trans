# 02 — 캡처·오버레이 스파이크

**What to build:** iOS 18+에서 ReplayKit 브로드캐스트 → 로컬 루프백 → PiP 창으로, 다른 앱 위에 현재 화면을 띄우는 우회 기법(ADR-0002)을 검증한다. 번역 없이, Safari 같은 타 앱 위에 라이브 화면이 뜨는 것만 확인한다. 이 경로가 실패하면 이후 모든 티켓의 전제가 흔들리므로 가장 먼저 해결하는 리스크.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] 스크린 녹화 권한을 받으면, 타 앱이 전면에 있는 동안 라이브 화면이 PiP 창으로 뜬다
- [ ] PiP 창이 아래 앱의 조작을 막지 않고, 시스템 PiP 방식으로 이동/크기/닫기가 된다
- [ ] 키보드가 켜진 화면, 세로/가로 회전 화면에서도 스트림이 끊기지 않는다
- [ ] 결과(RPSystemBroadcastPicker/루프백/PiP 경로의 성공·실패 요인)를 티켓 하단의 Answer 형식으로 기록한다