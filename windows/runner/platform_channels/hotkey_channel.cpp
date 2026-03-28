#include "hotkey_channel.h"

#include <flutter/encodable_value.h>

HotkeyChannel* HotkeyChannel::instance_ = nullptr;

HotkeyChannel::HotkeyChannel(flutter::BinaryMessenger* messenger)
    : method_channel_(messenger, "com.yap.hotkey",
                      &flutter::StandardMethodCodec::GetInstance()),
      event_channel_(messenger, "com.yap.hotkey/events",
                     &flutter::StandardMethodCodec::GetInstance()) {
  instance_ = this;

  method_channel_.SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  auto handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     events) {
            event_sink_ = std::move(events);
            return std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>();
          },
          [this](const flutter::EncodableValue* arguments) {
            event_sink_ = nullptr;
            return std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>();
          });

  event_channel_.SetStreamHandler(std::move(handler));
}

HotkeyChannel::~HotkeyChannel() {
  StopMonitoring();
  instance_ = nullptr;
}

void HotkeyChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "start") {
    int threshold = 400;
    if (call.arguments()) {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        auto it = args->find(flutter::EncodableValue("threshold"));
        if (it != args->end()) {
          threshold = std::get<int>(it->second);
        }
      }
    }
    StartMonitoring(threshold);
    result->Success();
  } else if (call.method_name() == "stop") {
    StopMonitoring();
    result->Success();
  } else if (call.method_name() == "setThreshold") {
    if (call.arguments()) {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        auto it = args->find(flutter::EncodableValue("threshold"));
        if (it != args->end()) {
          int val = std::get<int>(it->second);
          threshold_ms_ = std::max(200, std::min(600, val));
        }
      }
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void HotkeyChannel::StartMonitoring(int threshold_ms) {
  threshold_ms_ = threshold_ms;
  last_tap_valid_ = false;

  if (hook_) return;  // Already monitoring.

  hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc, nullptr, 0);
}

void HotkeyChannel::StopMonitoring() {
  if (hook_) {
    UnhookWindowsHookEx(hook_);
    hook_ = nullptr;
  }
}

LRESULT CALLBACK HotkeyChannel::LowLevelKeyboardProc(int nCode, WPARAM wParam,
                                                       LPARAM lParam) {
  if (nCode == HC_ACTION && instance_) {
    auto* kbd = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);

    // Detect Left Alt key-down (WM_KEYDOWN or WM_SYSKEYDOWN).
    if (kbd->vkCode == VK_LMENU &&
        (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN)) {
      auto now = std::chrono::steady_clock::now();

      if (instance_->last_tap_valid_) {
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                           now - instance_->last_tap_time_)
                           .count();

        if (elapsed > 0 && elapsed <= instance_->threshold_ms_) {
          // Double-tap detected.
          instance_->last_tap_valid_ = false;
          if (instance_->event_sink_) {
            instance_->event_sink_->Success(flutter::EncodableValue());
          }
        } else {
          instance_->last_tap_time_ = now;
          instance_->last_tap_valid_ = true;
        }
      } else {
        instance_->last_tap_time_ = now;
        instance_->last_tap_valid_ = true;
      }
    }
  }

  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}
