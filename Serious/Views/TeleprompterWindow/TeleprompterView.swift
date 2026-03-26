import SwiftUI

struct TeleprompterView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.windowCornerRadius)
                .fill(.black)

            if let script = viewModel.currentScript {
                ScriptTextView(script: script)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    // Fade out at bottom edge
                    .mask(
                        VStack(spacing: 0) {
                            Color.white
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                        }
                    )
            } else {
                VStack(spacing: 8) {
                    Text("No script loaded")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Open the menu bar to load a script")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: settings.windowWidth, height: Constants.defaultWindowHeight)
        .clipShape(RoundedRectangle(cornerRadius: Constants.windowCornerRadius))
        .background(WindowAccessor())
    }
}
