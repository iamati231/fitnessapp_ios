import Testing
import FitnessAppUI

/// Tests for MockSpeechRecognizer lifecycle — guards the contract that
/// onFinished fires at most once and cancelRecording() suppresses it.
struct MockSpeechRecognizerTests {

    // MARK: - Successful recording

    @Test func finishedCalledWithPreset() {
        let mock = MockSpeechRecognizer(preset: "Bankdrücken 80 Kilo acht Wiederholungen")
        var received: String?
        mock.onFinished = { received = $0 }
        try? mock.startRecording()
        #expect(received == "Bankdrücken 80 Kilo acht Wiederholungen")
    }

    @Test func emptyPresetFinishesWithNil() {
        let mock = MockSpeechRecognizer(preset: "")
        var received: String? = "sentinel"
        mock.onFinished = { received = $0 }
        try? mock.startRecording()
        #expect(received == nil)
    }

    // MARK: - Stop after recording

    @Test func stopAfterStartDoesNotDoubleCallback() {
        let mock = MockSpeechRecognizer(preset: "test")
        var callCount = 0
        mock.onFinished = { _ in callCount += 1 }
        try? mock.startRecording()
        mock.stopRecording()   // already delivered on startRecording — must not fire again
        #expect(callCount == 1)
    }

    // MARK: - Cancel suppresses callback

    @Test func cancelBeforeStartProducesNoCallback() {
        let mock = MockSpeechRecognizer(preset: "test")
        var called = false
        mock.onFinished = { _ in called = true }
        mock.cancelRecording()
        #expect(!called)
    }

    @Test func cancelDuringRecordingSuppressesCallback() {
        // Simulate cancellation happening synchronously while startRecording is "in progress".
        // With the synchronous mock this means cancelRecording sets a flag before onFinished
        // would fire — we test this by cancelling in the onTranscriptionUpdate callback.
        let mock = MockSpeechRecognizer(preset: "test")
        var finished = false
        mock.onTranscriptionUpdate = { _ in mock.cancelRecording() }
        mock.onFinished = { _ in finished = true }
        try? mock.startRecording()
        #expect(!finished)
    }

    // MARK: - Repeated recordings

    @Test func repeatedStartsEachDeliverOneCallback() {
        let mock = MockSpeechRecognizer(preset: "first")
        var results: [String?] = []
        mock.onFinished = { results.append($0) }

        try? mock.startRecording()
        mock.preset = "second"
        try? mock.startRecording()

        #expect(results.count == 2)
        #expect(results[0] == "first")
        #expect(results[1] == "second")
    }

    @Test func cancelThenRestartDeliversCallback() {
        let mock = MockSpeechRecognizer(preset: "hello")
        var callCount = 0
        mock.onFinished = { _ in callCount += 1 }

        mock.cancelRecording()
        try? mock.startRecording()

        #expect(callCount == 1)
    }

    // MARK: - Permission

    @Test func requestPermissionGranted() async {
        let mock = MockSpeechRecognizer()
        await withCheckedContinuation { cont in
            mock.requestPermission { granted in
                cont.resume()
                #expect(granted)
            }
        }
    }
}
