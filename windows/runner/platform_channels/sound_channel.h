#ifndef RUNNER_PLATFORM_CHANNELS_SOUND_CHANNEL_H_
#define RUNNER_PLATFORM_CHANNELS_SOUND_CHANNEL_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>

/// Handles the com.yap.sound platform channel on Windows.
///
/// Plays native Windows system sounds.
class SoundChannel {
 public:
  explicit SoundChannel(flutter::BinaryMessenger* messenger);
  ~SoundChannel() = default;

  SoundChannel(const SoundChannel&) = delete;
  SoundChannel& operator=(const SoundChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::MethodChannel<flutter::EncodableValue> method_channel_;
};

#endif  // RUNNER_PLATFORM_CHANNELS_SOUND_CHANNEL_H_
