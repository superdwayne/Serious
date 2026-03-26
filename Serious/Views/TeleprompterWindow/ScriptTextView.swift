import SwiftUI

struct ScriptTextView: View {
    let script: Script
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                let currentIndex = viewModel.scrollState.currentWordIndex
                FlowLayout(horizontalSpacing: settings.fontSize * 0.3, verticalSpacing: settings.fontSize * 0.4) {
                    ForEach(script.words) { word in
                        Text(word.text)
                            .font(.system(size: settings.fontSize, weight: .regular))
                            .foregroundColor(word.id <= currentIndex ? settings.readColor : settings.upcomingColor)
                            .id("word-\(word.id)")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                // Extra bottom padding so text can scroll past the visible area
                .padding(.bottom, 250)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: viewModel.scrollState.currentWordIndex) { _, newIndex in
                guard !viewModel.scrollState.isPaused else { return }
                withAnimation(.linear(duration: 0.8)) {
                    proxy.scrollTo("word-\(newIndex)", anchor: .top)
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    struct CachedLayout {
        var positions: [CGPoint]
        var size: CGSize
    }

    func makeCache(subviews: Subviews) -> CachedLayout? {
        nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CachedLayout?) -> CGSize {
        let result = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        cache = result
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CachedLayout?) {
        let layout = cache ?? arrange(width: bounds.width, subviews: subviews)
        for (index, position) in layout.positions.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> CachedLayout {
        var positions: [CGPoint] = []
        positions.reserveCapacity(subviews.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
            maxWidth = max(maxWidth, x - horizontalSpacing)
        }

        return CachedLayout(
            positions: positions,
            size: CGSize(width: maxWidth, height: y + rowHeight)
        )
    }
}
