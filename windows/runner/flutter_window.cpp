#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <optional>
#include <shellapi.h>
#include <string>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "fumic/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setFullscreen") {
          const auto* fullscreen = std::get_if<bool>(call.arguments());
          SetFullscreen(fullscreen != nullptr && *fullscreen);
          result->Success();
          return;
        }
        if (call.method_name() == "toggleFullscreen") {
          ToggleFullscreen();
          result->Success(flutter::EncodableValue(IsFullscreen()));
          return;
        }
        if (call.method_name() == "close") {
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "minimize") {
          ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success();
          return;
        }
        if (call.method_name() == "openUrl") {
          const auto* url = std::get_if<std::string>(call.arguments());
          if (url == nullptr || url->rfind("https://", 0) != 0 ||
              url->size() > 8192 || url->find('\0') != std::string::npos) {
            result->Error("invalid_url", "Expected an HTTPS URL.");
            return;
          }
          const int length = MultiByteToWideChar(
              CP_UTF8, MB_ERR_INVALID_CHARS, url->c_str(), -1, nullptr, 0);
          if (length == 0) {
            result->Error("invalid_url", "URL is not valid UTF-8.");
            return;
          }
          std::wstring wide_url(length, L'\0');
          MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, url->c_str(), -1,
                              wide_url.data(), length);
          // Open the default browser directly; command shells are blocked in
          // Windows S mode and are unnecessary for opening a web page.
          const auto status = reinterpret_cast<INT_PTR>(ShellExecuteW(
              GetHandle(), L"open", wide_url.c_str(), nullptr, nullptr,
              SW_SHOWNORMAL));
          if (status <= 32) {
            result->Error("open_url_failed", "Windows could not open the URL.");
            return;
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_KEYDOWN && wparam == 'W' &&
      (GetKeyState(VK_CONTROL) & 0x8000)) {
    PostMessage(hwnd, WM_CLOSE, 0, 0);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
