import Cocoa
import FlutterMacOS
import AVFoundation

/// Handles the `com.yap.audio` platform channel.
///
/// Uses AVAudioEngine to capture microphone audio and convert it to
/// 16kHz mono 16-bit PCM as required by AssemblyAI.
class AudioCaptureChannel: NSObject, FlutterStreamHandler {
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    private var audioEngine: AVAudioEngine?
    private var isCapturing = false

    /// Target format: 16 kHz, mono, 16-bit signed integer (little-endian).
    private let targetSampleRate: Double = 16000.0
    private let targetChannels: AVAudioChannelCount = 1

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.yap.audio",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.yap.audio/samples",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
        eventChannel.setStreamHandler(self)
    }

    // MARK: - MethodChannel handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCapture":
            startCapture(result: result)
        case "stopCapture":
            stopCapture(result: result)
        case "hasPermission":
            result(hasPermission())
        case "requestPermission":
            requestPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission

    private func hasPermission() -> Bool {
        if #available(macOS 10.14, *) {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
        return true
    }

    private func requestPermission(result: @escaping FlutterResult) {
        if #available(macOS 10.14, *) {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        } else {
            result(true)
        }
    }

    // MARK: - Capture

    private func startCapture(result: @escaping FlutterResult) {
        guard !isCapturing else {
            result(nil)
            return
        }

        guard hasPermission() else {
            result(FlutterError(
                code: "NO_PERMISSION",
                message: "Microphone permission not granted",
                details: nil
            ))
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            result(FlutterError(
                code: "FORMAT_ERROR",
                message: "Could not create target audio format",
                details: nil
            ))
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            result(FlutterError(
                code: "CONVERTER_ERROR",
                message: "Could not create audio converter",
                details: nil
            ))
            return
        }

        // ~100 ms of audio at 16 kHz = 1600 frames.
        let frameCapacity: AVAudioFrameCount = 1600

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] (buffer, _) in
            guard let self = self, let sink = self.eventSink else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCapacity
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            // Extract raw bytes from the converted buffer.
            if let channelData = convertedBuffer.int16ChannelData {
                let frameLength = Int(convertedBuffer.frameLength)
                let byteCount = frameLength * MemoryLayout<Int16>.size
                let data = Data(bytes: channelData[0], count: byteCount)
                DispatchQueue.main.async {
                    sink(FlutterStandardTypedData(bytes: data))
                }
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            isCapturing = true
            result(nil)
        } catch {
            result(FlutterError(
                code: "ENGINE_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    private func stopCapture(result: @escaping FlutterResult) {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isCapturing = false
        result(nil)
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
