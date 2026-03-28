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
#include <string>
#include <thread>
#include <vector>

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
      const std::string& device_id,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopCapture(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ListDevices(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void CaptureThreadProc();

  flutter::MethodChannel<flutter::EncodableValue> method_channel_;
  flutter::EventChannel<flutter::EncodableValue> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // Audio level event channel (sends RMS level 0.0-1.0)
  flutter::EventChannel<flutter::EncodableValue> level_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> level_sink_;

  std::atomic<bool> is_capturing_{false};
  std::thread capture_thread_;

  Microsoft::WRL::ComPtr<IAudioClient> audio_client_;
  Microsoft::WRL::ComPtr<IAudioCaptureClient> capture_client_;

  // Source format info (from device mix format)
  UINT32 source_sample_rate_ = 0;
  UINT32 source_channels_ = 0;
  UINT32 source_bits_per_sample_ = 0;
  bool source_is_float_ = false;
};

#endif  // RUNNER_PLATFORM_CHANNELS_AUDIO_CAPTURE_CHANNEL_H_
