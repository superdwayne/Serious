import Foundation

enum Constants {
    static let defaultWindowWidth: CGFloat = 600
    static let defaultWindowHeight: CGFloat = 300
    static let windowCornerRadius: CGFloat = 18
    static let windowBackgroundOpacity: Double = 0.85
    static let menuBarTopOffset: CGFloat = 28

    static let searchWindowBack: Int = 3
    static let searchWindowAhead: Int = 25
    static let defaultMatchThreshold: Double = 0.65
    static let defaultSilenceTimeout: TimeInterval = 2.0

    static let minWordsForMatch: Int = 1
    static let maxStepForward: Int = 10
    static let confirmationsRequired: Int = 2

    static let sfSpeechSessionLimit: TimeInterval = 55

    static let scriptsDirectoryName = "scripts"
    static let appSupportSubdirectory = "Serious"
}
