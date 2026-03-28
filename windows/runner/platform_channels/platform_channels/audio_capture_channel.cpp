#include "audio_capture_channel.h"

#include <flutter/encodable_value.h>
#include <functiondiscoverykeys_devpkey.h>

#include <cstring>
#include <vector>

AudioCaptureChannel::AudioCaptureChannel(flutter::BinaryMessenger* messenger)
    : method_channel_(messenger, "com.yap.audio",
                      &flutter::StandardMethodCodec::GetInstance()),
      event_channel_(messenger, "com.yap.audio/samples",
                     &flutter::StandardMethodCodec::GetInstance()) {
  method_channel_.SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                 events) {
        event_sink_ = std::move(events);
        return std::unique_ptr<
            flutter::StreamHandlerError<flutter::EncodableValue>>();
      },
      [this](const flutter::EncodableValue* arguments) {
        event_sink_ = nullptr;
        return std::unique_ptr<
            flutter::StreamHandlerError<flutter::EncodableValue>>();
      });

  event_channel_.SetStreamHandler(std::move(handler));
}

AudioCaptureChannel::~AudioCaptureChannel() {
  is_capturing_ = false;
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
}

void AudioCaptureChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "startCapture") {
    StartCapture(std::move(result));
  } else if (call.method_name() == "stopCapture") {
    StopCapture(std::move(result));
  } else if (call.method_name() == "hasPermission") {
    // Windows does not require explicit mic permission like macOS.
    result->Success(flutter::EncodableValue(true));
  } else if (call.method_name() == "requestPermission") {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

void AudioCaptureChannel::StartCapture(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (is_capturing_) {
    result->Success();
    return;
  }

  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    result->Error("COM_ERROR", "Failed to initialize COM");
    return;
  }

  // Get default audio capture device.
  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                        IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to create device enumerator");
    return;
  }

  Microsoft::WRL::ComPtr<IMMDevice> device;
  hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "No default capture device found");
    return;
  }

  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                         &audio_client_);
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to activate audio client");
    return;
  }

  // Request 16 kHz mono 16-bit PCM format.
  WAVEFORMATEX wfx = {};
  wfx.wFormatTag = WAVE_FORMAT_PCM;
  wfx.nChannels = 1;
  wfx.nSamplesPerSec = 16000;
  wfx.wBitsPerSample = 16;
  wfx.nBlockAlign = wfx.nChannels * wfx.wBitsPerSample / 8;
  wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;

  // Try to initialize with the requested format.
  // If the device doesn't support it, fall back to the device's mix format
  // and we would need resampling (not implemented in this stub).
  hr = audio_client_->Initialize(AUDCLNT_SHAREMODE_SHARED, 0,
                                  10000000,  // 1 second buffer
                                  0, &wfx, nullptr);
  if (FAILED(hr)) {
    // Fall back: try with the device's mix format.
    // TODO: Add resampling from mix format to 16kHz mono 16-bit.
    WAVEFORMATEX* mix_format = nullptr;
    audio_client_->GetMixFormat(&mix_format);
    hr = audio_client_->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 10000000, 0,
                                    mix_format, nullptr);
    if (mix_format) CoTaskMemFree(mix_format);
    if (FAILED(hr)) {
      result->Error("FORMAT_ERROR",
                     "Could not initialize audio capture with any format");
      return;
    }
  }

  hr = audio_client_->GetService(IID_PPV_ARGS(&capture_client_));
  if (FAILED(hr)) {
    result->Error("SERVICE_ERROR", "Failed to get capture client");
    return;
  }

  hr = audio_client_->Start();
  if (FAILED(hr)) {
    result->Error("START_ERROR", "Failed to start audio capture");
    return;
  }

  is_capturing_ = true;
  capture_thread_ = std::thread(&AudioCaptureChannel::CaptureThreadProc, this);

  result->Success();
}

void AudioCaptureChannel::StopCapture(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  is_capturing_ = false;
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
  if (audio_client_) {
    audio_client_->Stop();
  }
  audio_client_ = nullptr;
  capture_client_ = nullptr;
  result->Success();
}

void AudioCaptureChannel::CaptureThreadProc() {
  while (is_capturing_) {
    // Sleep ~100 ms to accumulate a chunk.
    Sleep(100);

    if (!capture_client_ || !is_capturing_) break;

    UINT32 packet_length = 0;
    HRESULT hr = capture_client_->GetNextPacketSize(&packet_length);
    if (FAILED(hr)) break;

    while (packet_length > 0 && is_capturing_) {
      BYTE* data = nullptr;
      UINT32 frames_available = 0;
      DWORD flags = 0;

      hr = capture_client_->GetBuffer(&data, &frames_available, &flags,
                                       nullptr, nullptr);
      if (FAILED(hr)) break;

      if (data && frames_available > 0 && event_sink_) {
        size_t byte_count = frames_available * 2;  // 16-bit mono = 2 bytes/frame
        std::vector<uint8_t> buffer(data, data + byte_count);
        event_sink_->Success(flutter::EncodableValue(buffer));
      }

      capture_client_->ReleaseBuffer(frames_available);

      hr = capture_client_->GetNextPacketSize(&packet_length);
      if (FAILED(hr)) break;
    }
  }
}
