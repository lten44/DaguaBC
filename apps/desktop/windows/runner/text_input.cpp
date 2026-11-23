#include "text_input.h"

#include <flutter/encodable_value.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <imm.h>

#include <atomic>
#include <filesystem>
#include <memory>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include "resource.h"
#include "win32_window.h"

namespace text_input {
namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
using Reply = flutter::MethodResult<EncodableValue>;
std::atomic<bool> active(false);

std::wstring ReadString(const EncodableMap& args, const char* key) {
  auto it = args.find(EncodableValue(key));
  if (it == args.end()) return {};
  const auto* text = std::get_if<std::string>(&it->second);
  if (!text || text->empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      text->data(), static_cast<int>(text->size()), nullptr, 0);
  if (size <= 0) throw std::runtime_error("Invalid UTF-8 text");
  std::wstring wide(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
      static_cast<int>(text->size()), wide.data(), size);
  return wide;
}

struct Prompt {
  std::wstring title, hint, initial, confirm, cancel;
  std::string value;
  bool dark = true;
  HFONT font = nullptr, title_font = nullptr;
  HBRUSH surface = nullptr, field = nullptr;
  RECT field_rect{};
  int scale(int pixels) const { return MulDiv(pixels, dpi, 96); }
  UINT dpi = 96;
  COLORREF background() const { return dark ? RGB(18, 22, 32) : RGB(255, 255, 255); }
  COLORREF foreground() const { return dark ? RGB(230, 232, 238) : RGB(21, 23, 28); }
  COLORREF secondary() const { return dark ? RGB(154, 160, 172) : RGB(90, 96, 107); }
  COLORREF field_color() const { return dark ? RGB(35, 36, 47) : RGB(233, 235, 239); }
  ~Prompt() {
    if (font) DeleteObject(font);
    if (title_font) DeleteObject(title_font);
    if (surface) DeleteObject(surface);
    if (field) DeleteObject(field);
  }
};

void RoundFill(HDC dc, const RECT& rect, int radius, COLORREF fill, COLORREF border) {
  HPEN pen = CreatePen(PS_SOLID, 1, border);
  HBRUSH brush = CreateSolidBrush(fill);
  HGDIOBJ old_pen = SelectObject(dc, pen), old_brush = SelectObject(dc, brush);
  RoundRect(dc, rect.left, rect.top, rect.right, rect.bottom, radius, radius);
  SelectObject(dc, old_pen);
  SelectObject(dc, old_brush);
  DeleteObject(pen);
  DeleteObject(brush);
}

INT_PTR CALLBACK DialogProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto* prompt = reinterpret_cast<Prompt*>(GetWindowLongPtr(hwnd, DWLP_USER));
  if (message == WM_INITDIALOG) {
    prompt = reinterpret_cast<Prompt*>(lparam);
    SetWindowLongPtr(hwnd, DWLP_USER, lparam);
    // DialogBox may add a caption/frame from the resource title. Remove it
    // before laying out in client pixels so the custom buttons cannot clip.
    SetWindowLongPtr(hwnd, GWL_STYLE, GetWindowLongPtr(hwnd, GWL_STYLE) &
        ~(WS_CAPTION | WS_THICKFRAME | WS_BORDER | WS_DLGFRAME));
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, GetWindowLongPtr(hwnd, GWL_EXSTYLE) &
        ~WS_EX_DLGMODALFRAME);
    SetWindowTextW(hwnd, prompt->title.c_str());
    SetDlgItemTextW(hwnd, IDC_TEXT_TITLE, prompt->title.c_str());
    SetDlgItemTextW(hwnd, IDC_TEXT_HINT, prompt->hint.c_str());
    SetDlgItemTextW(hwnd, IDC_TEXT_VALUE, prompt->initial.c_str());
    SetDlgItemTextW(hwnd, IDOK, prompt->confirm.c_str());
    SetDlgItemTextW(hwnd, IDCANCEL, prompt->cancel.c_str());
    HWND edit = GetDlgItem(hwnd, IDC_TEXT_VALUE);
    SendMessage(edit, EM_SETLIMITTEXT, 512, 0);
    SendMessage(edit, EM_SETSEL, 0, -1);
    prompt->dpi = GetDpiForWindow(GetParent(hwnd));
    prompt->surface = CreateSolidBrush(prompt->background());
    prompt->field = CreateSolidBrush(prompt->field_color());
    prompt->font = CreateFontW(-prompt->scale(13), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH, L"Source Han Sans SC");
    prompt->title_font = CreateFontW(-prompt->scale(17), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH, L"Source Han Sans SC Medium");
    for (int id : {IDC_TEXT_HINT, IDC_TEXT_VALUE, IDOK, IDCANCEL}) {
      SendDlgItemMessage(hwnd, id, WM_SETFONT, reinterpret_cast<WPARAM>(prompt->font), TRUE);
    }
    SendDlgItemMessage(hwnd, IDC_TEXT_TITLE, WM_SETFONT, reinterpret_cast<WPARAM>(prompt->title_font), TRUE);
    auto place = [hwnd, prompt](int id, int x, int y, int width, int height) {
      MoveWindow(GetDlgItem(hwnd, id), prompt->scale(x), prompt->scale(y),
          prompt->scale(width), prompt->scale(height), TRUE);
    };
    place(IDC_TEXT_TITLE, 24, 22, 412, 28);
    place(IDC_TEXT_HINT, 24, 58, 412, 22);
    place(IDC_TEXT_VALUE, 37, 96, 386, 24);
    place(IDCANCEL, 256, 154, 80, 36);
    place(IDOK, 348, 154, 88, 36);
    prompt->field_rect = {prompt->scale(24), prompt->scale(86), prompt->scale(436), prompt->scale(130)};
    RECT owner_rect{};
    GetWindowRect(GetParent(hwnd), &owner_rect);
    SetWindowPos(hwnd, nullptr,
        owner_rect.left + ((owner_rect.right - owner_rect.left) - prompt->scale(460)) / 2,
        owner_rect.top + ((owner_rect.bottom - owner_rect.top) - prompt->scale(214)) / 2,
        prompt->scale(460), prompt->scale(214), SWP_NOZORDER | SWP_FRAMECHANGED);
    SetWindowRgn(hwnd, CreateRoundRectRgn(0, 0, prompt->scale(460), prompt->scale(214),
        prompt->scale(16), prompt->scale(16)), TRUE);
    SendMessage(hwnd, DM_SETDEFID, IDOK, 0);
    SetFocus(edit);
    return FALSE;
  }
  if (prompt && message == WM_PAINT) {
    PAINTSTRUCT paint{};
    HDC dc = BeginPaint(hwnd, &paint);
    RECT rect{};
    GetClientRect(hwnd, &rect);
    FillRect(dc, &rect, prompt->surface);
    RoundFill(dc, rect, prompt->scale(16), prompt->background(),
        prompt->dark ? RGB(49, 52, 63) : RGB(203, 208, 216));
    RoundFill(dc, prompt->field_rect, prompt->scale(12), prompt->field_color(), RGB(255, 107, 44));
    EndPaint(hwnd, &paint);
    return TRUE;
  }
  if (prompt && (message == WM_CTLCOLORSTATIC || message == WM_CTLCOLOREDIT)) {
    HDC dc = reinterpret_cast<HDC>(wparam);
    const int id = GetDlgCtrlID(reinterpret_cast<HWND>(lparam));
    SetTextColor(dc, id == IDC_TEXT_HINT ? prompt->secondary() : prompt->foreground());
    SetBkColor(dc, id == IDC_TEXT_VALUE ? prompt->field_color() : prompt->background());
    return reinterpret_cast<INT_PTR>(id == IDC_TEXT_VALUE ? prompt->field : prompt->surface);
  }
  if (prompt && message == WM_DRAWITEM) {
    const auto* item = reinterpret_cast<DRAWITEMSTRUCT*>(lparam);
    if (item->CtlType != ODT_BUTTON) return FALSE;
    const bool primary = item->CtlID == IDOK;
    const bool pressed = (item->itemState & ODS_SELECTED) != 0;
    const COLORREF fill = primary ? (pressed ? RGB(231, 91, 30) : RGB(255, 107, 44)) : prompt->background();
    FillRect(item->hDC, &item->rcItem, prompt->surface);
    RoundFill(item->hDC, item->rcItem, prompt->scale(12), fill, fill);
    SetBkMode(item->hDC, TRANSPARENT);
    SetTextColor(item->hDC, primary ? RGB(26, 14, 6) : prompt->secondary());
    SelectObject(item->hDC, prompt->font);
    RECT text_rect = item->rcItem;
    const auto& label = primary ? prompt->confirm : prompt->cancel;
    DrawTextW(item->hDC, label.c_str(), -1, &text_rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    if ((item->itemState & ODS_FOCUS) != 0) {
      InflateRect(&text_rect, -prompt->scale(4), -prompt->scale(4));
      DrawFocusRect(item->hDC, &text_rect);
    }
    return TRUE;
  }
  if (message == WM_COMMAND && prompt) {
    if (LOWORD(wparam) == IDCANCEL) {
      EndDialog(hwnd, IDCANCEL);
      return TRUE;
    }
    if (LOWORD(wparam) == IDOK) {
      HWND edit = GetDlgItem(hwnd, IDC_TEXT_VALUE);
      HIMC ime = ImmGetContext(edit);
      const bool composing = ime && ImmGetCompositionStringW(ime, GCS_COMPSTR, nullptr, 0) > 0;
      if (ime) ImmReleaseContext(edit, ime);
      if (composing) return TRUE;
      std::vector<wchar_t> buffer(GetWindowTextLengthW(edit) + 1);
      GetWindowTextW(edit, buffer.data(), static_cast<int>(buffer.size()));
      const int size = WideCharToMultiByte(CP_UTF8, 0, buffer.data(), -1, nullptr, 0, nullptr, nullptr);
      if (size <= 0) return TRUE;
      prompt->value.resize(size);
      WideCharToMultiByte(CP_UTF8, 0, buffer.data(), -1, prompt->value.data(), size, nullptr, nullptr);
      prompt->value.resize(size - 1);
      EndDialog(hwnd, IDOK);
      return TRUE;
    }
  }
  return FALSE;
}
}  // namespace

void Register(flutter::FlutterEngine* engine, HWND owner) {
  wchar_t executable[MAX_PATH];
  if (GetModuleFileNameW(nullptr, executable, MAX_PATH)) {
    const auto fonts = std::filesystem::path(executable).parent_path() /
        L"data/flutter_assets/assets/fonts";
    for (const auto* name : {L"SourceHanSansSC-Regular.otf", L"SourceHanSansSC-Medium.otf"}) {
      if (!AddFontResourceExW((fonts / name).c_str(), FR_PRIVATE, nullptr)) {
        OutputDebugStringW(L"DaguaBC: unable to load bundled Source Han Sans font.\n");
      }
    }
  }
  auto channel = std::make_shared<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "daguabc/native_text_input",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([channel, owner](const auto& call, std::unique_ptr<Reply> reply) {
    if (call.method_name() != "prompt") { reply->NotImplemented(); return; }
    const auto* args = call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
    if (!args) { reply->Error("invalid_arguments", "Text prompt arguments are missing."); return; }
    if (active.exchange(true)) { reply->Error("dialog_already_open", "A text prompt is already open."); return; }
    auto pending = std::make_shared<std::unique_ptr<Reply>>(std::move(reply));
    try {
      auto prompt = std::make_shared<Prompt>();
      prompt->title = ReadString(*args, "title");
      prompt->hint = ReadString(*args, "hint");
      prompt->initial = ReadString(*args, "initialText");
      prompt->confirm = ReadString(*args, "confirmLabel");
      prompt->cancel = ReadString(*args, "cancelLabel");
      auto dark = args->find(EncodableValue("dark"));
      if (dark != args->end()) {
        if (const auto* enabled = std::get_if<bool>(&dark->second)) prompt->dark = *enabled;
      }
      std::thread([owner, pending, prompt = std::move(prompt)]() mutable {
        // A native EDIT on its own STA avoids Flutter's stale IMM32/TSF bridge.
        const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        const INT_PTR result = SUCCEEDED(com)
            ? DialogBoxParamW(GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDD_TEXT_INPUT),
                owner, DialogProc, reinterpret_cast<LPARAM>(prompt.get()))
            : -1;
        if (SUCCEEDED(com)) CoUninitialize();
        Win32Window::PostUiTask(owner, [pending, result, value = std::move(prompt->value)] {
          active.store(false);
          if (result == -1) (*pending)->Error("dialog_error", "The system text input could not be opened.");
          else if (result == IDOK) (*pending)->Success(EncodableValue(value));
          else (*pending)->Success(EncodableValue());
        });
      }).detach();
    } catch (const std::exception&) {
      active.store(false);
      (*pending)->Error("dialog_error", "The system text input could not be opened.");
    }
  });
}
}  // namespace text_input
