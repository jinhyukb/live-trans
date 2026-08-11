import SwiftUI
import ReplayKit
import LiveTransCore

struct SessionToggleView: View {
    @EnvironmentObject private var model: LiveTransModel

    var body: some View {
        VStack(spacing: 20) {
            Text("live-trans")
                .font(.largeTitle.bold())
            Text(isSessionActive ? "번역이 진행 중입니다" : "번역 세션이 꺼져 있습니다")
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle("번역", isOn: Binding(
                get: { isSessionActive },
                set: { _ in
                    model.toggle()
                    handleSessionChange()
                }
            ))
            .labelsHidden()
            .controlSize(.large)

            if model.onboardingState != .completed {
                Button("온보딩 다시 보기") {
                    // 온보딩은 앱 재설치 후 다시 안내됩니다.
                }
            }

            BroadcastPicker()

            if model.captionShown {
                CaptionStatusView()
            }
        }
        .padding()
        .onChange(of: model.sessionState) { _, _ in }
    }

    private var isSessionActive: Bool {
        switch model.sessionState {
        case .active, .starting, .paused: return true
        case .ended, .stopping: return false
        }
    }

    private func handleSessionChange() {
        if isSessionActive {
            try? model.startCapture()
        } else {
            model.stopCapture()
        }
    }
}

struct CaptionStatusView: View {
    @EnvironmentObject private var model: LiveTransModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch model.captionState {
            case .ready(let blocks):
                Text(blocks.first?.translatedText ?? "")
                    .font(.body)
            case .inPlaceReady(let layout):
                Text("제자리 번역 활성 (\(layout.placements.count)블록)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .preparing:
                Label("번역 준비 중...", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            case .needsSourceSelection:
                SourceSelectionView()
            case .failed:
                Label("번역 실패", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            case .idle:
                EmptyView()
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SourceSelectionView: View {
    @EnvironmentObject private var model: LiveTransModel

    var body: some View {
        HStack {
            Text("원문 언어를 선택하세요")
            Picker("원문 언어", selection: Binding(
                get: { Language.english },
                set: { model.manualSource($0) }
            )) {
                Text("영어").tag(Language.english)
                Text("일본어").tag(Language.japanese)
            }
            .pickerStyle(.segmented)
        }
    }
}