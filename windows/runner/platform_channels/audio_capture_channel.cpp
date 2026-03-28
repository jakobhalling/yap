#include "audio_capture_channel.h"

#include <flutter/encodable_value.h>
#include <functiondiscoverykeys_devpkey.h>

#include <cmath>
#include <cstring>
#include <vector>

static const UINT32 kTargetSampleRate = 16000;
static const UINT32 kTargetChannels = 1;
static const UINT32 kTargetBitsPerSample = 16;

AudioCaptureChannel::AudioCaptureChannel(flutter::BinaryMessenger* messenger)
    : method_channel_(messenger, "com.yap.audio",
                      &flutter::StandardMethodCodec::GetInstance()),
      event_channel_(messenger, "com.yap.audio/samples",
                     &flutter::StandardMethodCodec::GetInstance()),
      level_channel_(messenger, "com.yap.audio/level",
                     &flutter::StandardMethodCodec::GetInstance()) {
  method_channel_.SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                 events) {
        event_sink_ = std::move(events);
        return std::unique_ptr<
            flutter::StreamHandlerError<flutter::EncodableValue>>();
      },
      [this](const flutter::EncodableValue* arguments) {
        event_sink_ = nullptr;
        return std::unique_ptr<
            flutter::StreamHandlerError<flutter::EncodableValue>>();
      });
  event_channel_.SetStreamHandler(std::move(handler));

  auto level_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                 events) {
        level_sink_ = std::move(events);
        return std::unique_ptr<
            flutter::StreamHandlerError<flutter::EncodableValue>>();
      },
      [this](const flutter::EncodableValue* arguments) {
        level_sink_ = nullptr;
        return std::unique_ptr<
            flutter::StreamHandlerError<flutter::EncodableValue>>();
      });
  level_channel_.SetStreamHandler(std::move(level_handler));
}

AudioCaptureChannel::~AudioCaptureChannel() {
  is_capturing_ = false;
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
}

void AudioCaptureChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "startCapture") {
    std::string device_id;
    if (call.arguments()) {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        auto it = args->find(flutter::EncodableValue("deviceId"));
        if (it != args->end()) {
          const auto* id = std::get_if<std::string>(&it->second);
          if (id) device_id = *id;
        }
      }
    }
    StartCapture(device_id, std::move(result));
  } else if (call.method_name() == "stopCapture") {
    StopCapture(std::move(result));
  } else if (call.method_name() == "listDevices") {
    ListDevices(std::move(result));
  } else if (call.method_name() == "hasPermission") {
    result->Success(flutter::EncodableValue(true));
  } else if (call.method_name() == "requestPermission") {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

void AudioCaptureChannel::ListDevices(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to create device enumerator");
    return;
  }

  Microsoft::WRL::ComPtr<IMMDeviceCollection> collection;
  hr = enumerator->EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE,
                                       &collection);
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to enumerate devices");
    return;
  }

  // Get default device ID for comparison
  std::wstring default_id;
  {
    Microsoft::WRL::ComPtr<IMMDevice> default_device;
    if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eCapture, eConsole,
                                                       &default_device))) {
      LPWSTR id = nullptr;
      if (SUCCEEDED(default_device->GetId(&id)) && id) {
        default_id = id;
        CoTaskMemFree(id);
      }
    }
  }

  UINT count = 0;
  collection->GetCount(&count);

  flutter::EncodableList devices;

  for (UINT i = 0; i < count; i++) {
    Microsoft::WRL::ComPtr<IMMDevice> device;
    if (FAILED(collection->Item(i, &device))) continue;

    LPWSTR id_raw = nullptr;
    if (FAILED(device->GetId(&id_raw)) || !id_raw) continue;
    std::wstring wide_id(id_raw);
    CoTaskMemFree(id_raw);

    // Convert wide ID to UTF-8
    int utf8_len = WideCharToMultiByte(CP_UTF8, 0, wide_id.c_str(), -1,
                                        nullptr, 0, nullptr, nullptr);
    std::string id(utf8_len - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, wide_id.c_str(), -1, &id[0], utf8_len,
                        nullptr, nullptr);

    // Get friendly name
    std::string name = "Unknown Device";
    Microsoft::WRL::ComPtr<IPropertyStore> props;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &props))) {
      PROPVARIANT var;
      PropVariantInit(&var);
      if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &var))) {
        if (var.vt == VT_LPWSTR && var.pwszVal) {
          int name_len = WideCharToMultiByte(CP_UTF8, 0, var.pwszVal, -1,
                                              nullptr, 0, nullptr, nullptr);
          name.resize(name_len - 1);
          WideCharToMultiByte(CP_UTF8, 0, var.pwszVal, -1, &name[0],
                              name_len, nullptr, nullptr);
        }
        PropVariantClear(&var);
      }
    }

    bool is_default = (wide_id == default_id);

    flutter::EncodableMap device_map;
    device_map[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
    device_map[flutter::EncodableValue("name")] =
        flutter::EncodableValue(name);
    device_map[flutter::EncodableValue("isDefault")] =
        flutter::EncodableValue(is_default);
    devices.push_back(flutter::EncodableValue(device_map));
  }

  result->Success(flutter::EncodableValue(devices));
}

void AudioCaptureChannel::StartCapture(
    const std::string& device_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (is_capturing_) {
    result->Success();
    return;
  }

  HRESULT hr;

  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                        IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to create device enumerator");
    return;
  }

  Microsoft::WRL::ComPtr<IMMDevice> device;
  if (device_id.empty()) {
    hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
  } else {
    // Convert UTF-8 device_id to wide string
    int wide_len = MultiByteToWideChar(CP_UTF8, 0, device_id.c_str(), -1,
                                        nullptr, 0);
    std::wstring wide_id(wide_len - 1, 0);
    MultiByteToWideChar(CP_UTF8, 0, device_id.c_str(), -1, &wide_id[0],
                        wide_len);
    hr = enumerator->GetDevice(wide_id.c_str(), &device);
  }

  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to get capture device");
    return;
  }

  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                         &audio_client_);
  if (FAILED(hr)) {
    result->Error("DEVICE_ERROR", "Failed to activate audio client");
    return;
  }

  WAVEFORMATEX* mix_format = nullptr;
  hr = audio_client_->GetMixFormat(&mix_format);
  if (FAILED(hr) || !mix_format) {
    result->Error("FORMAT_ERROR", "Failed to get device mix format");
    return;
  }

  source_sample_rate_ = mix_format->nSamplesPerSec;
  source_channels_ = mix_format->nChannels;
  source_bits_per_sample_ = mix_format->wBitsPerSample;
  source_is_float_ = false;

  if (mix_format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) {
    source_is_float_ = true;
  } else if (mix_format->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
    auto* ext = reinterpret_cast<WAVEFORMATEXTENSIBLE*>(mix_format);
    if (ext->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT) {
      source_is_float_ = true;
    }
  }

  hr = audio_client_->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 10000000, 0,
                                  mix_format, nullptr);
  CoTaskMemFree(mix_format);

  if (FAILED(hr)) {
    result->Error("FORMAT_ERROR", "Could not initialize audio capture");
    return;
  }

  hr = audio_client_->GetService(IID_PPV_ARGS(&capture_client_));
  if (FAILED(hr)) {
    result->Error("SERVICE_ERROR", "Failed to get capture client");
    return;
  }

  hr = audio_client_->Start();
  if (FAILED(hr)) {
    result->Error("START_ERROR", "Failed to start audio capture");
    return;
  }

  is_capturing_ = true;
  capture_thread_ = std::thread(&AudioCaptureChannel::CaptureThreadProc, this);

  result->Success();
}

void AudioCaptureChannel::StopCapture(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  is_capturing_ = false;
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
  if (audio_client_) {
    audio_client_->Stop();
  }
  audio_client_ = nullptr;
  capture_client_ = nullptr;
  result->Success();
}

static float SampleToFloat(const BYTE* data, int bits_per_sample,
                           bool is_float) {
  if (is_float && bits_per_sample == 32) {
    float val;
    memcpy(&val, data, sizeof(float));
    return val;
  }
  if (bits_per_sample == 16) {
    int16_t val;
    memcpy(&val, data, sizeof(int16_t));
    return val / 32768.0f;
  }
  if (bits_per_sample == 24) {
    int32_t val = (data[0]) | (data[1] << 8) | (data[2] << 16);
    if (val & 0x800000) val |= 0xFF000000;
    return val / 8388608.0f;
  }
  if (bits_per_sample == 32 && !is_float) {
    int32_t val;
    memcpy(&val, data, sizeof(int32_t));
    return val / 2147483648.0f;
  }
  return 0.0f;
}

void AudioCaptureChannel::CaptureThreadProc() {
  const double ratio =
      static_cast<double>(kTargetSampleRate) / source_sample_rate_;
  const int bytes_per_source_sample = source_bits_per_sample_ / 8;
  const int source_frame_size = bytes_per_source_sample * source_channels_;

  double src_pos = 0.0;
  int level_counter = 0;

  while (is_capturing_) {
    Sleep(50);

    if (!capture_client_ || !is_capturing_) break;

    UINT32 packet_length = 0;
    HRESULT hr = capture_client_->GetNextPacketSize(&packet_length);
    if (FAILED(hr)) break;

    std::vector<int16_t> output_samples;
    float rms_sum = 0.0f;
    int rms_count = 0;

    while (packet_length > 0 && is_capturing_) {
      BYTE* data = nullptr;
      UINT32 frames_available = 0;
      DWORD flags = 0;

      hr = capture_client_->GetBuffer(&data, &frames_available, &flags,
                                       nullptr, nullptr);
      if (FAILED(hr)) break;

      if (data && frames_available > 0 && !(flags & AUDCLNT_BUFFERFLAGS_SILENT)) {
        for (UINT32 i = 0; i < frames_available; i++) {
          // Mono mix
          float mono = 0.0f;
          for (UINT32 ch = 0; ch < source_channels_; ch++) {
            const BYTE* sample_ptr =
                data + (i * source_frame_size) +
                (ch * bytes_per_source_sample);
            mono += SampleToFloat(sample_ptr, source_bits_per_sample_,
                                  source_is_float_);
          }
          mono /= source_channels_;

          // RMS accumulator (on source samples for accuracy)
          rms_sum += mono * mono;
          rms_count++;

          // Resample: check if this source frame produces an output sample
          double out_idx_now = src_pos * ratio;
          double out_idx_prev = (src_pos > 0) ? (src_pos - 1) * ratio : -1;
          if (static_cast<int>(out_idx_now) > static_cast<int>(out_idx_prev)) {
            if (mono > 1.0f) mono = 1.0f;
            if (mono < -1.0f) mono = -1.0f;
            int16_t pcm = static_cast<int16_t>(mono * 32767.0f);
            output_samples.push_back(pcm);
          }
          src_pos += 1.0;
        }
      }

      capture_client_->ReleaseBuffer(frames_available);

      hr = capture_client_->GetNextPacketSize(&packet_length);
      if (FAILED(hr)) break;
    }

    // Send audio data
    if (!output_samples.empty() && event_sink_) {
      size_t byte_count = output_samples.size() * sizeof(int16_t);
      std::vector<uint8_t> buffer(byte_count);
      memcpy(buffer.data(), output_samples.data(), byte_count);
      event_sink_->Success(flutter::EncodableValue(buffer));
    }

    // Send audio level (~every 150ms = every 3rd iteration)
    level_counter++;
    if (level_counter >= 3 && rms_count > 0 && level_sink_) {
      float rms = sqrtf(rms_sum / rms_count);
      // Scale to 0-1 range with some amplification for visibility
      float level = fminf(1.0f, rms * 3.0f);
      level_sink_->Success(flutter::EncodableValue(static_cast<double>(level)));
      level_counter = 0;
    }
  }
}
