#include "paste_channel.h"

#include <flutter/encodable_value.h>

#include <thread>
#include <chrono>

PasteChannel::PasteChannel(flutter::BinaryMessenger* messenger)
    : method_channel_(messenger, "com.yap.paste",
                      &flutter::StandardMethodCodec::GetInstance()) {
  method_channel_.SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

void PasteChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "paste") {
    std::string text;
    if (call.arguments()) {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        auto it = args->find(flutter::EncodableValue("text"));
        if (it != args->end()) {
          text = std::get<std::string>(it->second);
        }
      }
    }
    if (text.empty()) {
      result->Error("INVALID_ARGS", "Expected non-empty 'text' argument");
      return;
    }
    bool success = PasteText(text);
    result->Success(flutter::EncodableValue(success));
  } else {
    result->NotImplemented();
  }
}

bool PasteChannel::PasteText(const std::string& text) {
  // 1. Save current clipboard contents.
  std::wstring previous = GetClipboardText();

  // 2. Convert UTF-8 text to wide string and set on clipboard.
  int wide_len = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  std::wstring wide_text(wide_len - 1, 0);
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, &wide_text[0], wide_len);
  SetClipboardText(wide_text);

  // 3. Simulate Ctrl+V.
  SimulateCtrlV();

  // 4. Wait briefly, then restore the original clipboard.
  std::thread([previous, this]() {
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
    SetClipboardText(previous);
  }).detach();

  return true;
}

std::wstring PasteChannel::GetClipboardText() {
  std::wstring result;
  if (OpenClipboard(nullptr)) {
    HANDLE data = GetClipboardData(CF_UNICODETEXT);
    if (data) {
      wchar_t* text = static_cast<wchar_t*>(GlobalLock(data));
      if (text) {
        result = text;
        GlobalUnlock(data);
      }
    }
    CloseClipboard();
  }
  return result;
}

void PasteChannel::SetClipboardText(const std::wstring& text) {
  if (!OpenClipboard(nullptr)) return;

  EmptyClipboard();

  size_t size = (text.size() + 1) * sizeof(wchar_t);
  HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, size);
  if (mem) {
    wchar_t* dest = static_cast<wchar_t*>(GlobalLock(mem));
    if (dest) {
      memcpy(dest, text.c_str(), size);
      GlobalUnlock(mem);
      SetClipboardData(CF_UNICODETEXT, mem);
    }
  }

  CloseClipboard();
}

void PasteChannel::SimulateCtrlV() {
  INPUT inputs[4] = {};

  // Ctrl down
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = VK_CONTROL;

  // V down
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = 'V';

  // V up
  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = 'V';
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

  // Ctrl up
  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

  SendInput(4, inputs, sizeof(INPUT));
}
