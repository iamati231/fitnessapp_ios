import Foundation

// MARK: - Protocol

public protocol SpeechRecognizing: AnyObject {
    var onTranscriptionUpdate: ((String) -> Void)? { get set }
    var onFinished: ((String?) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func requestPermission(completion: @escaping (Bool) -> Void)
    func startRecording() throws
    /// Graceful stop: ends audio input; onFinished fires when recognition completes.
    func stopRecording()
    /// Immediate abort: cancels recognition and cleans up. onFinished is NOT called.
    func cancelRecording()
}

// MARK: - Live Recognizer

#if canImport(Speech) && canImport(AVFoundation)
import Speech
import AVFoundation

/// Live microphone-based recognizer using Apple's Speech framework.
/// Lifecycle rules:
///   startRecording() — begins a new session (aborts any prior one).
///   stopRecording()  — signals end of audio; recognition finalizes and fires onFinished.
///   cancelRecording()— aborts immediately; onFinished is never called.
///   onFinished fires at most once per session.
@available(iOS 17.0, macOS 14.0, *)
public final class LiveSpeechRecognizer: NSObject, SpeechRecognizing {

    public var onTranscriptionUpdate: ((String) -> Void)?
    public var onFinished: ((String?) -> Void)?
    public var onError: ((Error) -> Void)?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var lastTranscript: String?
    // Rotated on each new session and on cancel to invalidate stale callbacks.
    private var sessionToken: UUID = UUID()
    // Set when stopRecording() is called so error callbacks from endAudio() are treated as
    // normal completion rather than unexpected failures.
    private var isStopping = false

    public override init() {
        let locale = Locale.current
        speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        speechRecognizer?.delegate = self
    }

    public func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { completion(false); return }
                #if os(iOS)
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async { completion(granted) }
                }
                #else
                completion(true)
                #endif
            }
        }
    }

    public func startRecording() throws {
        // Abort any prior session without delivering a callback
        invalidateSession()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.notAvailable
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        engine.prepare()
        try engine.start()

        let token = sessionToken
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, self.sessionToken == token else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.lastTranscript = transcript
                self.onTranscriptionUpdate?(transcript)
                if result.isFinal {
                    self.stopEngine()
                    self.deliver(self.lastTranscript)
                }
            } else if let error {
                self.stopEngine()
                let nsError = error as NSError
                // Treat "no speech" (1110) and any error after an intentional stop as
                // silent completion — use the last partial transcript.
                let isSilentFinish = self.isStopping
                    || (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110)
                if isSilentFinish {
                    self.deliver(self.lastTranscript)
                } else {
                    // Rotate token before calling onError so any in-flight callback is dropped.
                    self.sessionToken = UUID()
                    self.recognitionTask = nil
                    self.recognitionRequest = nil
                    self.onError?(error)
                }
            }
        }
    }

    public func stopRecording() {
        isStopping = true
        recognitionRequest?.endAudio()
        stopEngine()
        // recognitionTask remains active and will fire deliver() when the ASR finalizes.
    }

    public func cancelRecording() {
        invalidateSession()
    }

    // MARK: - Private

    /// Rotate the session token (drops stale callbacks) and cancel the active task.
    private func invalidateSession() {
        sessionToken = UUID()
        isStopping = false
        lastTranscript = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        stopEngine()
    }

    /// Fire onFinished, then rotate the token so any duplicate callback is dropped.
    private func deliver(_ text: String?) {
        sessionToken = UUID() // rotate first; the outer closure guard prevents re-entry
        isStopping = false
        recognitionTask = nil
        recognitionRequest = nil
        onFinished?(text)
    }

    private func stopEngine() {
        guard engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension LiveSpeechRecognizer: SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ recognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available { onError?(SpeechError.notAvailable) }
    }
}

#endif // canImport(Speech)

// MARK: - Error

public enum SpeechError: LocalizedError {
    case notAvailable
    case permissionDenied
    case engineFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable: return String(localized: "voice.error.notAvailable", bundle: .module)
        case .permissionDenied: return String(localized: "voice.error.permissionDenied", bundle: .module)
        case .engineFailed(let msg): return msg
        }
    }
}

// MARK: - Mock (for tests)

/// Synchronously delivers a preset transcript on startRecording().
/// cancelRecording() suppresses the callback — useful for lifecycle tests.
public final class MockSpeechRecognizer: SpeechRecognizing {
    public var preset: String
    public var onTranscriptionUpdate: ((String) -> Void)?
    public var onFinished: ((String?) -> Void)?
    public var onError: ((Error) -> Void)?
    private var cancelled = false

    public init(preset: String = "") {
        self.preset = preset
    }

    public func requestPermission(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    public func startRecording() {
        cancelled = false
        let text = preset.isEmpty ? nil : preset
        onTranscriptionUpdate?(preset)
        if !cancelled {
            onFinished?(text)
        }
    }

    public func stopRecording() {
        // For mock, audio was already delivered synchronously in startRecording.
    }

    public func cancelRecording() {
        cancelled = true
    }
}
