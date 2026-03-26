import Speech
import AVFoundation

struct TranscriptionResult: Sendable {
    let text: String
    let isFinal: Bool
    let words: [String]
    let timestamp: Date

    init(text: String, isFinal: Bool = false) {
        self.text = text
        self.isFinal = isFinal
        self.words = text.split(separator: /\s+/).map(String.init)
        self.timestamp = Date()
    }
}

protocol SpeechServiceProtocol: Sendable {
    func startTranscription(locale: String) -> AsyncStream<TranscriptionResult>
    func stopTranscription() async
}

final class LegacySpeechService: SpeechServiceProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.serious.speech", qos: .userInitiated)
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var continuation: AsyncStream<TranscriptionResult>.Continuation?
    private var sessionRestartTask: Task<Void, Never>?
    private var isRestarting = false

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscription(locale: String) -> AsyncStream<TranscriptionResult> {
        AsyncStream { continuation in
            self.queue.async {
                self.continuation = continuation
                let loc = Locale(identifier: locale)
                self.recognizer = SFSpeechRecognizer(locale: loc)
                self.startAudioEngine()
                self.startRecognitionSession()
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                Task { await self.stopTranscription() }
            }
        }
    }

    /// Creates and starts AVAudioEngine once. Must be called on `queue`.
    private func startAudioEngine() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            continuation?.finish()
            return
        }

        // The tap stays installed for the lifetime of the service.
        // It forwards buffers to whatever recognitionRequest is current.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            inputNode.removeTap(onBus: 0)
            continuation?.finish()
        }
    }

    /// Starts a new SFSpeechRecognitionTask (reuses the running audio engine). Must be called on `queue`.
    private func startRecognitionSession() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let recognizer, audioEngine != nil else {
            continuation?.finish()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcription = TranscriptionResult(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal
                )
                self.continuation?.yield(transcription)
            }

            if error != nil || (result?.isFinal == true) {
                self.queue.async { self.restartRecognitionSession() }
            }
        }

        scheduleSessionRestart()
    }

    private func scheduleSessionRestart() {
        sessionRestartTask?.cancel()
        sessionRestartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.sfSpeechSessionLimit))
            guard !Task.isCancelled, let self else { return }
            self.queue.async { self.restartRecognitionSession() }
        }
    }

    /// Tears down only the recognition request/task and starts a new one. Audio engine keeps running.
    private func restartRecognitionSession() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isRestarting else { return }
        isRestarting = true

        tearDownRecognitionSession()

        guard continuation != nil else {
            isRestarting = false
            return
        }

        // Small delay so the previous recognition task fully winds down
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
            guard let self, self.continuation != nil else {
                self?.isRestarting = false
                return
            }
            self.isRestarting = false
            self.startRecognitionSession()
        }
    }

    private func tearDownRecognitionSession() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func tearDownAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    func stopTranscription() async {
        await withCheckedContinuation { cont in
            queue.async {
                self.sessionRestartTask?.cancel()
                self.sessionRestartTask = nil
                self.isRestarting = false
                self.continuation?.finish()
                self.continuation = nil
                self.tearDownRecognitionSession()
                self.tearDownAudioEngine()
                cont.resume()
            }
        }
    }
}

@available(macOS 26.0, *)
final class ModernSpeechService: SpeechServiceProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.serious.modern-speech", qos: .userInitiated)
    private var analyzerTask: Task<Void, Never>?
    private var analyzer: SpeechAnalyzer?
    private var audioEngine: AVAudioEngine?

    func startTranscription(locale: String) -> AsyncStream<TranscriptionResult> {
        AsyncStream { continuation in
            analyzerTask = Task {
                do {
                    let transcriber = SpeechTranscriber(
                        locale: Locale(identifier: locale),
                        preset: .progressiveTranscription
                    )
                    let analyzer = SpeechAnalyzer(modules: [transcriber])
                    self.analyzer = analyzer

                    let engine = AVAudioEngine()
                    self.audioEngine = engine
                    let inputNode = engine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)

                    guard format.sampleRate > 0, format.channelCount > 0 else {
                        continuation.finish()
                        return
                    }

                    let audioStream = AsyncStream<AnalyzerInput> { audioContinuation in
                        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                            audioContinuation.yield(AnalyzerInput(buffer: buffer))
                        }
                        audioContinuation.onTermination = { @Sendable [weak self] _ in
                            self?.queue.async {
                                self?.audioEngine?.inputNode.removeTap(onBus: 0)
                                self?.audioEngine?.stop()
                                self?.audioEngine = nil
                            }
                        }
                    }

                    try engine.start()
                    try await analyzer.start(inputSequence: audioStream)

                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        let transcriptionResult = TranscriptionResult(text: text)
                        continuation.yield(transcriptionResult)
                    }
                } catch {
                    self.queue.async {
                        self.audioEngine?.inputNode.removeTap(onBus: 0)
                        self.audioEngine?.stop()
                        self.audioEngine = nil
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                self?.analyzerTask?.cancel()
                Task {
                    await self?.analyzer?.cancelAndFinishNow()
                }
            }
        }
    }

    func stopTranscription() async {
        analyzerTask?.cancel()
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
        analyzerTask = nil
        queue.sync {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            audioEngine = nil
        }
    }
}

enum SpeechServiceFactory {
    static func create(locale: String) async -> any SpeechServiceProtocol {
        // Try modern SpeechAnalyzer API on macOS 26+
        if #available(macOS 26.0, *) {
            do {
                if SpeechTranscriber.isAvailable {
                    let transcriber = SpeechTranscriber(
                        locale: Locale(identifier: locale),
                        preset: .progressiveTranscription
                    )
                    let status = await AssetInventory.status(forModules: [transcriber])
                    if status >= .installed {
                        return ModernSpeechService()
                    }
                }
            } catch {
                // Modern API unavailable, fall through to legacy
            }
        }
        return LegacySpeechService()
    }
}
