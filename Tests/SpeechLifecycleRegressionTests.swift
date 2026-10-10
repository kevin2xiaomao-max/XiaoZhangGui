import XCTest
@testable import XiaoZhangGui

final class SpeechLifecycleRegressionTests: XCTestCase {
    func testAudioFormatRejectsZeroSampleRateAndZeroChannels() {
        XCTAssertFalse(SpeechAudioFormatPolicy.isUsable(sampleRate: 0, channelCount: 1))
        XCTAssertFalse(SpeechAudioFormatPolicy.isUsable(sampleRate: 44_100, channelCount: 0))
        XCTAssertFalse(SpeechAudioFormatPolicy.isUsable(sampleRate: .nan, channelCount: 1))
        XCTAssertTrue(SpeechAudioFormatPolicy.isUsable(sampleRate: 44_100, channelCount: 1))
    }

    func testStartGateRejectsDuplicateAndInvalidatesPendingStart() {
        var gate = SpeechStartGate()
        let first = gate.begin()
        XCTAssertNotNil(first)
        XCTAssertNil(gate.begin())
        XCTAssertTrue(gate.isCurrent(first!))
        gate.end()
        XCTAssertFalse(gate.isCurrent(first!))
        XCTAssertNotNil(gate.begin())
    }

    @MainActor
    func testPermissionDenialDoesNotStartAudio() async {
        let speech = FakeSpeechService(permission: false)
        let recorder = QuickRecordVoiceRecorder(speech: speech)
        recorder.start { _ in XCTFail("Denied permission must not finish recognition") }
        await settle()
        XCTAssertEqual(recorder.status, .denied)
        XCTAssertEqual(speech.startCount, 0)
    }

    @MainActor
    func testCancelWhilePermissionIsPendingPreventsLateAudioStart() async {
        let speech = FakeSpeechService(permission: nil)
        let recorder = QuickRecordVoiceRecorder(speech: speech)
        recorder.start { _ in XCTFail("Cancelled session must ignore late permission") }
        await settle()
        recorder.cancel()
        speech.resolvePermission(true)
        await settle()
        XCTAssertEqual(recorder.status, .idle)
        XCTAssertEqual(speech.startCount, 0)
        XCTAssertEqual(speech.cancelCount, 1)
    }

    @MainActor
    func testDuplicateStartStopAndCancelAreIdempotent() async {
        let speech = FakeSpeechService(permission: true)
        let recorder = QuickRecordVoiceRecorder(speech: speech)
        recorder.start { _ in }
        recorder.start { _ in XCTFail("Duplicate start must be ignored") }
        await settle()
        XCTAssertEqual(speech.permissionRequestCount, 1)
        XCTAssertEqual(speech.startCount, 1)
        recorder.stop()
        recorder.cancel()
        recorder.cancel()
        XCTAssertEqual(speech.stopCount, 1)
        XCTAssertEqual(speech.cancelCount, 2)
        XCTAssertEqual(recorder.status, .idle)
    }

    @MainActor
    private func settle() async {
        for _ in 0..<4 { await Task.yield() }
    }
}

@MainActor
private final class FakeSpeechService: SpeechServicing {
    let isRecognizerInitialized = true
    private var permission: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?
    private(set) var permissionRequestCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0

    init(permission: Bool?) { self.permission = permission }

    func requestPermissions() async -> Bool {
        permissionRequestCount += 1
        if let permission { return permission }
        return await withCheckedContinuation { continuation = $0 }
    }

    func resolvePermission(_ granted: Bool) {
        permission = granted
        continuation?.resume(returning: granted)
        continuation = nil
    }

    func start(
        partialHandler: @escaping (String) -> Void,
        finalHandler: @escaping (String) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) throws {
        startCount += 1
    }

    func stop() { stopCount += 1 }
    func cancel() { cancelCount += 1 }
}
