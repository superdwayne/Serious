import AppKit

@Observable
final class NotchDetector {
    var currentScreen: NSScreen?
    var hasNotch: Bool = false
    var cameraPosition: CGPoint = .zero
    var windowOrigin: CGPoint = .zero

    init() {
        updateScreenInfo()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateScreenInfo()
        }
    }

    func updateScreenInfo() {
        let screen = NSScreen.screenWithNotch ?? NSScreen.main ?? NSScreen.screens.first
        currentScreen = screen
        guard let screen else { return }

        hasNotch = screen.hasNotch
        cameraPosition = screen.cameraCenter

        calculateWindowOrigin(for: screen, windowWidth: 600)
    }

    func calculateWindowOrigin(for screen: NSScreen, windowWidth: CGFloat) {
        let centerX = screen.cameraCenter.x - windowWidth / 2
        let topY: CGFloat

        if screen.hasNotch {
            // Flush against the bottom of the menu bar — no gap
            topY = screen.frame.maxY - screen.safeAreaInsets.top - Constants.defaultWindowHeight
        } else {
            topY = screen.frame.maxY - Constants.menuBarTopOffset - Constants.defaultWindowHeight
        }

        windowOrigin = CGPoint(x: centerX, y: topY)
    }
}
