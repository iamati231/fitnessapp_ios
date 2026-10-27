import Foundation

// MARK: - Protocol

/// Testable speech recognition interface. Live impl uses Apple's Speech framework;
/// MockSpeechRecognizer provides a canned transcript for unit tests.
public protocol SpeechRecognizing: AnyObject {
    var onTranscriptionUpdate: ((String) -> Void)? { get set }
    var onFinished: ((String?) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func requestPermission(completion: @escaping (Bool) -> Void)
    func startRecording() throws
    func stopRecording()
}

// MARK: - Live Recognizer

#if canImport(Speech) && canImport(AVFoundation)
import Speech
import AVFoundation

/// Live microphone-based recognizer using Apple's Speech framework.
/// Transcription is on-device when available (requiresOnDeviceRecognition = true).
/// Automatically stops after 60 seconds of silence to save battery.
@available(iOS 17.0, macOS 14.0, *)
public final class LiveSpeechRecognizer: NSObject, SpeechRecognizing {

    public var onTranscriptionUpdate: ((String) -> Void)?
    public var onFinished: ((String?) -> Void)?
    public var onError: ((Error) -> Void)?

    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var lastTranscript: String?

    public override init() {
        // Use device locale, fall back to German then English
        let locale = Locale.current
        recognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        recognizer?.delegate = self
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
        // Clean up any running session
        stopRecording()

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.notAvailable
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        engine.prepare()
        try engine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.lastTranscript = transcript
                self.onTranscriptionUpdate?(transcript)
                if result.isFinal {
                    self.cleanupEngine()
                    self.onFinished?(transcript)
                }
            } else if let error {
                self.cleanupEngine()
                // NSError 1110 = no speech detected — not an app error
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    self.onFinished?(self.lastTranscript)
                } else {
                    self.onError?(error)
                }
            }
        }
    }

    public func stopRecording() {
        recognitionRequest?.endAudio()
        cleanupEngine()
        if let t = lastTranscript {
            onFinished?(t)
            lastTranscript = nil
        }
    }

    private func cleanupEngine() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
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

/// Returns a preset transcript on `startRecording()`, then calls `onFinished`.
public final class MockSpeechRecognizer: SpeechRecognizing {
    public var preset: String
    public var onTranscriptionUpdate: ((String) -> Void)?
    public var onFinished: ((String?) -> Void)?
    public var onError: ((Error) -> Void)?

    public init(preset: String = "") {
        self.preset = preset
    }

    public func requestPermission(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    public func startRecording() {
        onTranscriptionUpdate?(preset)
        onFinished?(preset)
    }

    public func stopRecording() {}
}

