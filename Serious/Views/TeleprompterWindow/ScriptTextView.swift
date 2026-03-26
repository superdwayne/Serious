import SwiftUI

struct ScriptTextView: View {
    let script: Script
    @Environment(AppSettings.self) private var settings
    @Environment(TeleprompterViewModel.self) private var viewModel
    @State private var wordRows: [Int: CGFloat] = [:]
    @State private var lastScrolledRow: CGFloat = -1

    var body: some View {
        let currentIndex = viewModel.scrollState.currentWordIndex

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                RowTrackingFlowLayout(
                    horizontalSpacing: settings.fontSize * 0.35,
                    verticalSpacing: settings.fontSize * 0.5,
                    wordRows: $wordRows
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
                let currentRow = wordRows[newIndex] ?? -1
                // Only scroll when the word is on a different row
                if currentRow != lastScrolledRow {
                    lastScrolledRow = currentRow
                    withAnimation(.easeOut(duration: 0.6)) {
                        proxy.scrollTo(newIndex, anchor: UnitPoint(x: 0.5, y: 0.1))
                    }
                }
            }
        }
    }
}

/// FlowLayout that reports each word's row Y position back via binding.
private struct RowTrackingFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat
    @Binding var wordRows: [Int: CGFloat]

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

        // Update row mapping
        var rows: [Int: CGFloat] = [:]
        for (index, position) in layout.positions.enumerated() {
            rows[index] = position.y
        }
        DispatchQueue.main.async {
            self.wordRows = rows
        }

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
