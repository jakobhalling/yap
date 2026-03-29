import Cocoa
import FlutterMacOS
import AVFoundation
import CoreAudio

/// Handles the `com.yap.audio` platform channel.
///
/// Uses AVAudioEngine to capture microphone audio and convert it to
/// 16kHz mono 16-bit PCM as required by AssemblyAI.
class AudioCaptureChannel: NSObject, FlutterStreamHandler {
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let levelChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var levelSink: FlutterEventSink?

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
        levelChannel = FlutterEventChannel(
            name: "com.yap.audio/level",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
        eventChannel.setStreamHandler(self)
        levelChannel.setStreamHandler(LevelStreamHandler(owner: self))
    }

    // MARK: - MethodChannel handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCapture":
            let deviceId = (call.arguments as? [String: Any])?["deviceId"] as? String
            startCapture(deviceId: deviceId, result: result)
        case "stopCapture":
            stopCapture(result: result)
        case "hasPermission":
            result(hasPermission())
        case "requestPermission":
            requestPermission(result: result)
        case "listDevices":
            result(listDevices())
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

    // MARK: - Device listing

    private func listDevices() -> [[String: Any]] {
        var devices: [[String: Any]] = []

        // Get the default input device ID.
        var defaultDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize,
            &defaultDeviceID
        )

        // Get all audio devices.
        address.mSelector = kAudioHardwarePropertyDevices
        propertySize = 0
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize
        )

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize,
            &deviceIDs
        )

        for deviceID in deviceIDs {
            // Check if this device has input channels.
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize) == noErr else {
                continue
            }

            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPointer.deallocate() }
            guard AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &inputSize, bufferListPointer) == noErr else {
                continue
            }

            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let inputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard inputChannels > 0 else { continue }

            // Get device name.
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)

            devices.append([
                "id": String(deviceID),
                "name": name as String,
                "isDefault": deviceID == defaultDeviceID,
            ])
        }

        return devices
    }

    // MARK: - Set input device

    private func setInputDevice(_ deviceIdString: String?) {
        guard let deviceIdString = deviceIdString,
              let deviceID = AudioDeviceID(deviceIdString) else {
            return
        }

        // Verify the device exists and has input.
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var inputSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize) == noErr else {
            return
        }

        // Set as default input device so AVAudioEngine picks it up.
        var mutableDeviceID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
    }

    // MARK: - Capture

    private func startCapture(deviceId: String?, result: @escaping FlutterResult) {
        guard !isCapturing else {
            result(nil)
            return
        }

        if !hasPermission() {
            // Request permission and retry if granted.
            if #available(macOS 10.14, *) {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.startCapture(deviceId: deviceId, result: result)
                        } else {
                            result(FlutterError(
                                code: "NO_PERMISSION",
                                message: "Microphone permission not granted",
                                details: nil
                            ))
                        }
                    }
                }
            } else {
                result(FlutterError(
                    code: "NO_PERMISSION",
                    message: "Microphone permission not granted",
                    details: nil
                ))
            }
            return
        }

        // Set the requested input device before starting the engine.
        if let deviceId = deviceId, !deviceId.isEmpty {
            setInputDevice(deviceId)
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
            guard let self = self else { return }

            // Calculate audio level (RMS) for the waveform visualization.
            if let channelData = buffer.floatChannelData {
                let frames = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frames {
                    let sample = channelData[0][i]
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(max(frames, 1)))
                let level = Double(min(rms * 3.0, 1.0)) // Scale up and clamp
                if let sink = self.levelSink {
                    DispatchQueue.main.async {
                        sink(level)
                    }
                }
            }

            // Convert to target format for transcription.
            guard let sink = self.eventSink else { return }

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

    // MARK: - FlutterStreamHandler (audio samples)

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Level stream handler helper
    fileprivate func setLevelSink(_ sink: FlutterEventSink?) {
        levelSink = sink
    }
}

/// Separate stream handler for the audio level event channel.
private class LevelStreamHandler: NSObject, FlutterStreamHandler {
    weak var owner: AudioCaptureChannel?

    init(owner: AudioCaptureChannel) {
        self.owner = owner
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        owner?.setLevelSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        owner?.setLevelSink(nil)
        return nil
    }
}
