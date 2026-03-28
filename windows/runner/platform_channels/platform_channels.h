#ifndef RUNNER_PLATFORM_CHANNELS_PLATFORM_CHANNELS_H_
#define RUNNER_PLATFORM_CHANNELS_PLATFORM_CHANNELS_H_

#include <flutter/flutter_engine.h>

#include "audio_capture_channel.h"
#include "hotkey_channel.h"
#include "paste_channel.h"

/// Register all Yap platform channels with the Flutter engine.
///
/// Call this from flutter_window.cpp after the engine is running.
inline void RegisterPlatformChannels(flutter::FlutterEngine* engine) {
  auto messenger = engine->messenger();
  // Channels are self-registering; constructing them is sufficient.
  static std::unique_ptr<HotkeyChannel> hotkey_channel;
  static std::unique_ptr<AudioCaptureChannel> audio_capture_channel;
  static std::unique_ptr<PasteChannel> paste_channel;

  hotkey_channel = std::make_unique<HotkeyChannel>(messenger);
  audio_capture_channel = std::make_unique<AudioCaptureChannel>(messenger);
  paste_channel = std::make_unique<PasteChannel>(messenger);
}

#endif  // RUNNER_PLATFORM_CHANNELS_PLATFORM_CHANNELS_H_
