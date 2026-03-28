import SwiftUI
import Speech
import AVFoundation

@Observable
@MainActor
final class TeleprompterViewModel {
    var currentScript: Script?
    var scrollState = ScrollState()
    var trackingError: String?
    var isTracking: Bool = false {
        didSet {
            if isTracking {
                trackingError = nil
                startTracking()
            } else {
                stopTracking()
            }
        }
    }

    private let wordMatcher = WordMatcher()
    private var speechService: (any SpeechServiceProtocol)?
    private var trackingTask: Task<Void, Never>?
    private var silenceTimer: Task<Void, Never>?
    private var lastTranscriptionTime: Date?
    private var settings: AppSettings?

    func configure(settings: AppSettings) {
        self.settings = settings
    }

    func loadScript(_ script: Script) {
        // Fully stop any active tracking before swapping the script
        if isTracking {
            isTracking = false
        }

        // Reset scroll and matcher state
        scrollState.reset()

        // Load new script
        currentScript = script
        scrollState.totalWords = script.wordCount
        wordMatcher.configure(
            script: script,
            sensitivity: settings?.matchSensitivity ?? Constants.defaultMatchThreshold
        )
    }

    func resetToBeginning() {
        if isTracking {
            isTracking = false
        }
        scrollState.reset()
        wordMatcher.reset()
        lastTranscriptionTime = nil
        trackingError = nil
    }

    private func startTracking() {
        guard currentScript != nil else {
            isTracking = false
            return
        }

        // Stop any previous session fully before starting a new one
        stopTracking()

        trackingTask = Task {
            do {
                try await performTracking()
            } catch is CancellationError {
                // Normal cancellation
            } catch {
                if !Task.isCancelled && isTracking {
                    trackingError = "Voice tracking failed: \(error.localizedDescription)"
                    isTracking = false
                }
            }
        }
    }

    private func performTracking() async throws {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                trackingError = "Microphone access denied"
                isTracking = false
                return
            }
        } else if micStatus != .authorized {
            trackingError = "Microphone access required — check System Settings"
            isTracking = false
            return
        }

        var speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            let granted = await Task.detached {
                await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                    SFSpeechRecognizer.requestAuthorization { status in
                        cont.resume(returning: status == .authorized)
                    }
                }
            }.value
            speechStatus = granted ? .authorized : .denied
        }
        guard speechStatus == .authorized else {
            trackingError = "Speech recognition denied — check System Settings"
            isTracking = false
            return
        }

        // Wait for any previous speech service to fully stop before creating a new one
        if let existingService = speechService {
            await existingService.stopTranscription()
            speechService = nil
        }

        let locale = settings?.speechLocale ?? "en-US"
        let deviceUID = settings?.audioInputDeviceUID
        let service = await SpeechServiceFactory.create(locale: locale)
        guard !Task.isCancelled else { return }
        speechService = service

        let stream = service.startTranscription(locale: locale, deviceUID: deviceUID)
        scrollState.isPaused = false
        scrollState.isScrolling = true
        lastTranscriptionTime = Date()
        startSilenceMonitor()

        var receivedAnyResult = false
        for await result in stream {
            try Task.checkCancellation()
            receivedAnyResult = true
            lastTranscriptionTime = Date()

            if scrollState.isPaused {
                scrollState.isPaused = false
            }

            if let newIndex = wordMatcher.processTranscription(result) {
                scrollState.advanceTo(newIndex)
            }
        }

        if !Task.isCancelled && isTracking {
            trackingError = receivedAnyResult
                ? "Voice tracking session ended — restarting may help"
                : "Could not start speech recognition — check microphone access"
            isTracking = false
        }
    }

    private func stopTracking() {
        let taskToCancel = trackingTask
        trackingTask = nil
        taskToCancel?.cancel()

        silenceTimer?.cancel()
        silenceTimer = nil
        lastTranscriptionTime = nil
        scrollState.isScrolling = false
        scrollState.isPaused = true

        let service = speechService
        speechService = nil
        if let service {
            Task { await service.stopTranscription() }
        }
    }

    private func startSilenceMonitor() {
        silenceTimer?.cancel()
        let timeout = settings?.silenceTimeout ?? Constants.defaultSilenceTimeout

        silenceTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }

                if let lastTime = lastTranscriptionTime,
                   Date().timeIntervalSince(lastTime) > timeout {
                    if !scrollState.isPaused {
                        scrollState.isPaused = true
                    }
                }
            }
        }
    }

    func togglePlayPause() {
        if isTracking {
            scrollState.isPaused.toggle()
        } else {
            isTracking = true
        }
    }

    func adjustSpeed(by delta: Double) {
        guard let settings else { return }
        settings.scrollSpeed = max(0.25, min(3.0, settings.scrollSpeed + delta))
    }

    func loadSampleScript() {
        let sampleText = """
        So I built a fully working macOS app in under two hours using a team of AI agents. \
        Let me walk you through exactly how I did it.

        The app is called Serious. It's a teleprompter that sits right next to your MacBook \
        camera, in the notch area. It follows your voice in real time so you never have to \
        touch a scroll button. You just talk and it keeps up.

        Here's the thing. I didn't write most of this code by hand. I used Claude Code as my \
        engineering team. Think of it like having a senior developer who never gets tired, never \
        loses context, and can research, build, and debug all at the same time.

        The first thing I did was describe what I wanted in plain English. A floating window \
        near the notch. Speech recognition that follows along. A menu bar interface with no \
        dock icon. That's it. That was my spec.

        From there, Claude scaffolded the entire Xcode project. Twenty nine Swift files. Models, \
        services, views, view models, utilities. All wired up with proper architecture. SwiftUI \
        for the interface, the Speech framework for voice recognition, AVFoundation for audio capture.

        The real magic is in the iteration loop. I would launch the app, try it, describe what \
        felt wrong, and get a fix in seconds. The icon isn't showing up. Fixed. The text kerning \
        looks off. Fixed. Voice tracking isn't moving the words. Let me add diagnostics, check \
        the logs, find the permission issue, and fix the initialization flow. All in one conversation.

        One of the trickiest parts was handling Apple's speech recognition. On macOS fifteen, you \
        have to use SFSpeechRecognizer which has a sixty second session limit. On macOS twenty six, \
        there's a new SpeechAnalyzer API. The AI agent researched both APIs by reading Apple's \
        actual framework interfaces, then built a dual engine with automatic fallback. That's the \
        kind of thing that would take a human developer half a day just to figure out.

        The voice following works by running a word matcher that compares what you're saying \
        against the script using fuzzy string matching. It uses Levenshtein distance with a \
        sliding window so it handles mispronunciations, skipped words, and even ad libs without \
        losing your place.

        When something broke, I didn't have to dig through stack traces alone. The agent would \
        read crash reports, identify the exact line, explain the root cause, and ship a fix. At \
        one point the app was crashing because a speech authorization callback was hitting the \
        wrong dispatch queue. The agent found it, moved the call to a detached task, and the \
        crash was gone.

        The whole process felt less like programming and more like directing. I was the product \
        person saying what I wanted and why. The AI was the engineering team figuring out how \
        and shipping it.

        Two hours. A native macOS app with real time speech recognition, fuzzy word matching, \
        a custom floating window system, and a full settings interface. That's not the future. \
        That's right now.

        If you want to try building something like this yourself, start with a clear idea of \
        what you want the app to do. Describe it conversationally. Let the agent ask you \
        questions. And don't be afraid to iterate fast. The whole point is that mistakes are \
        cheap when your feedback loop is measured in seconds, not hours.

        That's how you build with AI agents. Thanks for watching.
        """
        let script = Script(title: "Building with AI Agents", rawText: sampleText)
        loadScript(script)
    }
}
