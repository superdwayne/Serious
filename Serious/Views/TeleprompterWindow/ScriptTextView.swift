import SwiftUI

struct ScriptTextView: View {
    let script: Script
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel
    @State private var wordYPositions: [Int: CGFloat] = [:]
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        let currentIndex = viewModel.scrollState.currentWordIndex

        GeometryReader { _ in
            FlowLayout(horizontalSpacing: settings.fontSize * 0.3, verticalSpacing: settings.fontSize * 0.4) {
                ForEach(script.words) { word in
                    Text(word.text)
                        .font(.system(size: settings.fontSize, weight: .regular))
                        .foregroundColor(word.id <= currentIndex ? settings.readColor : settings.upcomingColor)
                        .background(
                            GeometryReader { geo in
                                Color.clear.anchorPreference(key: WordYPreference.self, value: .top) { anchor in
                                    [word.id: geo[anchor].y]
                                }
                            }
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -scrollOffset)
        }
        .clipped()
        .onPreferenceChange(WordYPreference.self) { positions in
            wordYPositions = positions
        }
        .onChange(of: currentIndex) { _, newIndex in
            guard !viewModel.scrollState.isPaused else { return }
            updateOffset(for: newIndex)
        }
    }

    private func updateOffset(for index: Int) {
        guard let targetY = wordYPositions[index] else { return }
        // Keep a small top margin so the current line isn't flush with the edge
        let offset = max(0, targetY - 8)
        withAnimation(.smooth(duration: 1.2)) {
            scrollOffset = offset
        }
    }
}

private struct WordYPreference: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
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
