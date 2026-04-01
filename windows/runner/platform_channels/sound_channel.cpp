#include "sound_channel.h"

#include <mmsystem.h>
#include <shlobj.h>

#pragma comment(lib, "winmm.lib")

SoundChannel::SoundChannel(flutter::BinaryMessenger* messenger)
    : method_channel_(messenger, "com.yap.sound",
                      &flutter::StandardMethodCodec::GetInstance()) {
  method_channel_.SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

void SoundChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "playStartSound") {
    // Windows Navigation Start sound — subtle, pleasant.
    PlaySoundW(L"C:\\Windows\\Media\\Speech On.wav", nullptr,
               SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
    result->Success();
  } else if (call.method_name() == "playStopSound") {
    // Windows speech off sound — pairs well with start.
    PlaySoundW(L"C:\\Windows\\Media\\Speech Off.wav", nullptr,
               SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
    result->Success();
  } else {
    result->NotImplemented();
  }
}
