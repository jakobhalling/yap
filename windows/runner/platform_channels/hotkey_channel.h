#ifndef RUNNER_PLATFORM_CHANNELS_HOTKEY_CHANNEL_H_
#define RUNNER_PLATFORM_CHANNELS_HOTKEY_CHANNEL_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <chrono>
#include <memory>
#include <string>
#include <unordered_map>

class HotkeyChannel {
 public:
  explicit HotkeyChannel(flutter::BinaryMessenger* messenger);
  ~HotkeyChannel();

  HotkeyChannel(const HotkeyChannel&) = delete;
  HotkeyChannel& operator=(const HotkeyChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void StartMonitoring(int threshold_ms);
  void StopMonitoring();
  void SetTriggerKey(const std::string& key);

  static LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam,
                                                 LPARAM lParam);

  flutter::MethodChannel<flutter::EncodableValue> method_channel_;
  flutter::EventChannel<flutter::EncodableValue> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  static HotkeyChannel* instance_;
  HHOOK hook_ = nullptr;
  int threshold_ms_ = 400;
  DWORD trigger_vk_ = VK_LMENU;  // Configurable trigger key

  // Map of key identifiers to VK codes
  static const std::unordered_map<std::string, DWORD> key_map_;

  // State machine for double-tap detection.
  enum class TapState { idle, first_down, first_up };
  TapState state_ = TapState::idle;
  std::chrono::steady_clock::time_point first_down_time_;
  std::chrono::steady_clock::time_point first_up_time_;
};

#endif  // RUNNER_PLATFORM_CHANNELS_HOTKEY_CHANNEL_H_
