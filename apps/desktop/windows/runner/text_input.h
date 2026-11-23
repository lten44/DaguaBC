#ifndef RUNNER_TEXT_INPUT_H_
#define RUNNER_TEXT_INPUT_H_

#include <windows.h>

namespace flutter {
class FlutterEngine;
}

namespace text_input {
void Register(flutter::FlutterEngine* engine, HWND owner);
}

#endif
