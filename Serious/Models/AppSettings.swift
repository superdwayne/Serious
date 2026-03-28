import SwiftUI

@Observable
final class AppSettings {
    var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var scrollSpeed: Double {
        didSet { UserDefaults.standard.set(scrollSpeed, forKey: "scrollSpeed") }
    }
    var windowOpacity: Double {
        didSet { UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity") }
    }
    var windowWidth: CGFloat {
        didSet { UserDefaults.standard.set(windowWidth, forKey: "windowWidth") }
    }
    var matchSensitivity: Double {
        didSet { UserDefaults.standard.set(matchSensitivity, forKey: "matchSensitivity") }
    }
    var silenceTimeout: TimeInterval {
        didSet { UserDefaults.standard.set(silenceTimeout, forKey: "silenceTimeout") }
    }
    var speechLocale: String {
        didSet { UserDefaults.standard.set(speechLocale, forKey: "speechLocale") }
    }
    var audioInputDeviceUID: String {
        didSet { UserDefaults.standard.set(audioInputDeviceUID, forKey: "audioInputDeviceUID") }
    }
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var textColor: Color { .white }
    var readColor: Color { .white.opacity(0.55) }
    var upcomingColor: Color { .white.opacity(0.85) }
    var highlightColor: Color { .yellow }

    init() {
        let defaults = UserDefaults.standard
        self.fontSize = defaults.object(forKey: "fontSize") as? CGFloat ?? 18
        self.scrollSpeed = defaults.object(forKey: "scrollSpeed") as? Double ?? 1.0
        self.windowOpacity = defaults.object(forKey: "windowOpacity") as? Double ?? 0.85
        self.windowWidth = defaults.object(forKey: "windowWidth") as? CGFloat ?? 600
        self.matchSensitivity = defaults.object(forKey: "matchSensitivity") as? Double ?? 0.7
        self.silenceTimeout = defaults.object(forKey: "silenceTimeout") as? TimeInterval ?? 2.0
        self.speechLocale = defaults.string(forKey: "speechLocale") ?? "en-US"
        self.audioInputDeviceUID = defaults.string(forKey: "audioInputDeviceUID") ?? ""
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }
}
