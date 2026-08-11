import SwiftUI
import ReplayKit

struct OnboardingView: View {
    @EnvironmentObject private var model: LiveTransModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "captions.bubble")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("화면 번역 시작 방법")
                .font(.title.bold())
            Text("다른 앱의 화면을 한국어로 바로 번역해 보여드립니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: "1", text: "아래 버튼으로 번역을 켭니다")
                stepRow(number: "2", text: "화면 공유 버튼을 눌러 live-trans 캡처를 선택합니다")
                stepRow(number: "3", text: "번역하고 싶은 앱으로 이동하면 캡션이 표시됩니다")
                stepRow(number: "4", text: "다시 앱으로 돌아와 번역을 끄면 종료됩니다")
            }
            .padding()

            Button {
                model.completeOnboarding()
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(.tint.opacity(0.2)))
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}