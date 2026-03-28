#ifndef RUNNER_PLATFORM_CHANNELS_PASTE_CHANNEL_H_
#define RUNNER_PLATFORM_CHANNELS_PASTE_CHANNEL_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

/// Handles the com.yap.paste platform channel on Windows.
///
/// Performs clipboard save -> set text -> simulate Ctrl+V -> restore.
class PasteChannel {
 public:
  explicit PasteChannel(flutter::BinaryMessenger* messenger);
  ~PasteChannel() = default;

  PasteChannel(const PasteChannel&) = delete;
  PasteChannel& operator=(const PasteChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool PasteText(const std::string& text);
  std::wstring GetClipboardText();
  void SetClipboardText(const std::wstring& text);
  void SimulateCtrlV();

  flutter::MethodChannel<flutter::EncodableValue> method_channel_;
};

#endif  // RUNNER_PLATFORM_CHANNELS_PASTE_CHANNEL_H_
