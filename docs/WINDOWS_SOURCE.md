# 在 Windows 从源码运行

准备 Flutter 3.44.8（Dart 3.12.2）、Visual Studio 2022 的 C++ 桌面开发组件、Python 3.12，以及 PATH 中可用的 `ffmpeg` 和 `ffprobe`。如 Flutter 提示无法为插件创建符号链接，按提示启用 Windows 开发者模式。

将源码解压到较短的路径，例如 `D:\src\DaguaBC`，避免 Windows C++ 编译器找不到深层插件文件。首次构建需要下载 Flutter 依赖和播放器使用的 libmpv、ANGLE 文件。下载中断或出现校验失败时，恢复对 GitHub 的访问后重试。

在源码根目录打开 PowerShell，准备 Python 环境。

```powershell
py -3.12 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt
ffmpeg -version
ffprobe -version
flutter doctor -v
```

从 BHE 上游获取 `bball_model.pt`，存到源码根目录的 `models\bball_model.pt`。用 `Get-FileHash models\bball_model.pt -Algorithm SHA256` 与模型说明的校验值对照。[模型来源及校验值](MODEL_AND_DATA_LICENSES.md)

```powershell
$env:BHE_REPO_ROOT = (Get-Location).Path
$env:BHE_PYTHON = (Resolve-Path .\.venv\Scripts\python.exe).Path
Set-Location apps\desktop
flutter pub get
flutter run -d windows --dart-define BHE_VERSION=0.2.21
```

如需验证 Windows Release 编译，在 `apps\desktop` 执行 `flutter build windows --release --dart-define BHE_VERSION=0.2.21`，产物在 `build\windows\x64\runner\Release`。按上述方式提供 Python、模型和 FFmpeg 后，可从同一个终端启动产物。该目录是编译结果，公开免安装包还需要整理配套运行时及其许可。

使用 CPU 即可运行。需要 DirectML 时，在根目录将 `requirements-dml.txt` 安装到同一个 Python 环境，用同一权重生成动态批量 ONNX。

```powershell
& .\.venv\Scripts\python.exe -m pip install -r requirements-dml.txt
& .\.venv\Scripts\python.exe .\scripts\export_mobile_model.py --model .\models\bball_model.pt --output .\models\bball_model.onnx --dynamic
```
