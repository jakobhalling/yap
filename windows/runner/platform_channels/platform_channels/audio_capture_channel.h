#ifndef RUNNER_PLATFORM_CHANNELS_AUDIO_CAPTURE_CHANNEL_H_
#define RUNNER_PLATFORM_CHANNELS_AUDIO_CAPTURE_CHANNEL_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <atomic>
#include <memory>
#include <thread>
#include <vector>

/// Handles the com.yap.audio platform channel on Windows.
///
/// Uses WASAPI to capture audio from the default input device and
/// delivers 16kHz mono 16-bit PCM chunks to Dart.
class AudioCaptureChannel {
 public:
  explicit AudioCaptureChannel(flutter::BinaryMessenger* messenger);
  ~AudioCaptureChannel();

  AudioCaptureChannel(const AudioCaptureChannel&) = delete;
  AudioCaptureChannel& operator=(const AudioCaptureChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void StartCapture(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopCapture(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void CaptureThreadProc();

  flutter::MethodChannel<flutter::EncodableValue> method_channel_;
  flutter::EventChannel<flutter::EncodableValue> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  std::atomic<bool> is_capturing_{false};
  std::thread capture_thread_;

  Microsoft::WRL::ComPtr<IAudioClient> audio_client_;
  Microsoft::WRL::ComPtr<IAudioCaptureClient> capture_client_;
};

#endif  // RUNNER_PLATFORM_CHANNELS_AUDIO_CAPTURE_CHANNEL_H_
