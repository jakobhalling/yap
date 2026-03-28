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
  state_ = TapState::idle;

  if (hook_) return;

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

    if (kbd->vkCode == VK_LMENU) {
      auto now = std::chrono::steady_clock::now();

      bool is_down = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
      bool is_up = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);

      // State machine for double-tap detection:
      //   idle -> first_down (on key down)
      //   first_down -> first_up (on quick key up, must be < threshold)
      //   first_up -> FIRE! (on second key down within threshold of first down)
      //
      // If the key is held down too long, reset to idle.
      // This prevents triggering on hold or alt-tab style usage.

      switch (instance_->state_) {
        case TapState::idle:
          if (is_down) {
            instance_->first_down_time_ = now;
            instance_->state_ = TapState::first_down;
          }
          break;

        case TapState::first_down:
          if (is_up) {
            // Key released — check it was a quick tap (not a hold)
            auto held_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                               now - instance_->first_down_time_)
                               .count();
            if (held_ms < instance_->threshold_ms_) {
              // Quick tap — advance to waiting for second tap
              instance_->first_up_time_ = now;
              instance_->state_ = TapState::first_up;
            } else {
              // Held too long — was a hold, not a tap
              instance_->state_ = TapState::idle;
            }
          } else if (is_down) {
            // Repeated key-down while held (key repeat) — ignore
          }
          break;

        case TapState::first_up:
          if (is_down) {
            // Second tap down — check timing from first tap
            auto gap_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                              now - instance_->first_up_time_)
                              .count();
            if (gap_ms <= instance_->threshold_ms_) {
              // Double-tap detected!
              instance_->state_ = TapState::idle;
              if (instance_->event_sink_) {
                instance_->event_sink_->Success(flutter::EncodableValue());
              }
            } else {
              // Too slow — treat this as a new first tap
              instance_->first_down_time_ = now;
              instance_->state_ = TapState::first_down;
            }
          }
          break;
      }
    } else {
      // A different key was pressed — reset the tap state.
      // This prevents alt+key combos from triggering.
      if (instance_->state_ != TapState::idle) {
        instance_->state_ = TapState::idle;
      }
    }
  }

  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}
