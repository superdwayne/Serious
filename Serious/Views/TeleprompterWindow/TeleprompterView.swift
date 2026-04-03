import SwiftUI

struct TeleprompterView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.windowCornerRadius)
                .fill(.black)

            if let script = viewModel.currentScript {
                VStack(spacing: 0) {
                    ScriptTextView(script: script)
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

                    // Status / error bar
                    if viewModel.scrollState.isOffScript {
                        Text("Off Script — read the highlighted words to get back on track")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)
                    } else if let error = viewModel.trackingError {
                        Text(error)
                            .font(.system(size: 9))
                            .foregroundStyle(.red.opacity(0.8))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
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
