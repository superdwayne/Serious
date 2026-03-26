import SwiftUI
import AppKit

struct ScriptTextView: View {
    let script: Script
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel

    /// Y offset for each row, computed once when script/font changes.
    @State private var rowYOffsets: [CGFloat] = [0]
    /// Maps word index → row number.
    @State private var wordRowMap: [Int] = []
    /// Current animated scroll offset.
    @State private var scrollOffset: CGFloat = 0
    @State private var lastRow: Int = 0

    var body: some View {
        let currentIndex = viewModel.scrollState.currentWordIndex

        GeometryReader { geo in
            FlowLayout(
                horizontalSpacing: settings.fontSize * 0.35,
                verticalSpacing: settings.fontSize * 0.5
            ) {
                ForEach(script.words) { word in
                    Text(word.text)
                        .font(.system(size: settings.fontSize, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .frame(width: geo.size.width, alignment: .center)
            .offset(y: -scrollOffset)
        }
        .clipped()
        .onAppear { computeLayout() }
        .onChange(of: script.id) { _, _ in computeLayout() }
        .onChange(of: settings.fontSize) { _, _ in computeLayout() }
        .onChange(of: settings.windowWidth) { _, _ in computeLayout() }
        .onChange(of: currentIndex) { _, newIndex in
            // Always allow reset to beginning (index 0), even when paused
            let isReset = newIndex == 0
            guard isReset || !viewModel.scrollState.isPaused else { return }
            guard newIndex < wordRowMap.count else { return }
            let row = wordRowMap[newIndex]
            if row != lastRow || isReset {
                lastRow = row
                let targetY = row < rowYOffsets.count ? rowYOffsets[row] : 0
                withAnimation(isReset ? .easeOut(duration: 0.3) : .easeInOut(duration: 0.8)) {
                    scrollOffset = targetY
                }
            }
        }
    }

    /// Pre-compute row Y offsets and word→row mapping using font metrics.
    private func computeLayout() {
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .medium)
        let availableWidth = settings.windowWidth - 16
        let hSpacing = settings.fontSize * 0.35
        let vSpacing = settings.fontSize * 0.5
        let lineHeight = font.ascender - font.descender + font.leading

        var rowY: [CGFloat] = [0]
        var wordToRow: [Int] = []
        var x: CGFloat = 0
        var currentRow = 0

        for word in script.words {
            let wordWidth = (word.text as NSString).size(withAttributes: [.font: font]).width
            if x + wordWidth > availableWidth && x > 0 {
                currentRow += 1
                let y = CGFloat(currentRow) * (lineHeight + vSpacing)
                rowY.append(y)
                x = wordWidth + hSpacing
            } else {
                x += wordWidth + hSpacing
            }
            wordToRow.append(currentRow)
        }

        rowYOffsets = rowY
        wordRowMap = wordToRow
        scrollOffset = 0
        lastRow = 0
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
