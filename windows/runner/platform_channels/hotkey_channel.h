#ifndef RUNNER_PLATFORM_CHANNELS_HOTKEY_CHANNEL_H_
#define RUNNER_PLATFORM_CHANNELS_HOTKEY_CHANNEL_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <chrono>
#include <functional>
#include <memory>
#include <mutex>

/// Handles the com.yap.hotkey platform channel on Windows.
///
/// Uses SetWindowsHookEx with WH_KEYBOARD_LL to detect double-taps
/// of Left Alt (VK_LMENU).
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

  static LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam,
                                                 LPARAM lParam);

  flutter::MethodChannel<flutter::EncodableValue> method_channel_;
  flutter::EventChannel<flutter::EncodableValue> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  static HotkeyChannel* instance_;
  HHOOK hook_ = nullptr;
  int threshold_ms_ = 400;
  std::chrono::steady_clock::time_point last_tap_time_;
  bool last_tap_valid_ = false;
};

#endif  // RUNNER_PLATFORM_CHANNELS_HOTKEY_CHANNEL_H_
