import SwiftUI
import AppKit

struct ScriptTextView: View {
    let script: Script
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel

    /// First word index on each visual row. Computed once per script/settings change.
    @State private var rowStartIndices: [Int] = []
    @State private var lastScrolledRow: Int = -1

    var body: some View {
        let currentIndex = viewModel.scrollState.currentWordIndex

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                FlowLayout(
                    horizontalSpacing: settings.fontSize * 0.35,
                    verticalSpacing: settings.fontSize * 0.5
                ) {
                    ForEach(script.words) { word in
                        Text(word.text)
                            .font(.system(size: settings.fontSize, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .id(word.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 300)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollDisabled(true)
            .onChange(of: currentIndex) { _, newIndex in
                guard !viewModel.scrollState.isPaused else { return }
                let row = rowForWord(newIndex)
                if row != lastScrolledRow {
                    lastScrolledRow = row
                    withAnimation(.easeOut(duration: 0.5)) {
                        proxy.scrollTo(newIndex, anchor: UnitPoint(x: 0.5, y: 0.1))
                    }
                }
            }
        }
        .onAppear { computeRows() }
        .onChange(of: settings.fontSize) { _, _ in computeRows() }
        .onChange(of: settings.windowWidth) { _, _ in computeRows() }
    }

    /// Pre-compute which word starts each visual row based on font metrics.
    private func computeRows() {
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .medium)
        let availableWidth = settings.windowWidth - 16 // horizontal padding
        let spacing = settings.fontSize * 0.35

        var starts: [Int] = [0]
        var x: CGFloat = 0

        for word in script.words {
            let wordWidth = (word.text as NSString).size(withAttributes: [.font: font]).width
            if x + wordWidth > availableWidth && x > 0 {
                starts.append(word.id)
                x = wordWidth + spacing
            } else {
                x += wordWidth + spacing
            }
        }
        rowStartIndices = starts
    }

    /// Find which row a word index belongs to.
    private func rowForWord(_ index: Int) -> Int {
        // Binary search for the last row start <= index
        var lo = 0, hi = rowStartIndices.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if rowStartIndices[mid] <= index {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
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
