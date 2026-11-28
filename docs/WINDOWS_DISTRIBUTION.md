# Windows x64 发行包与对应源码

DaguaBC 0.3.0 的 Windows 安装版按 [GNU AGPL-3.0](../LICENSE) 提供。感谢 Jafir、EddyLL06 及 BHE 的所有贡献者。安装包提供 [BHE 的原 MIT 许可](../LICENSES/BHE-MIT.txt) 和 [署名记录](../NOTICE)。字体、模型和独立的第三方运行组件沿用各自的条款。

## 应用与推理引擎

- 应用对应源码由同一 GitHub Release 提供，包含 Flutter 界面、Python 引擎、项目数据库定义、依赖清单、模型转换和安装器脚本。[构建说明](WINDOWS_SOURCE.md)
- Python 3.11.16 及第三方 Python 包随安装器提供，实际包版本记录于源码附件的 `runtime-requirements.txt`。安装目录中的包元数据和许可文件用于核对归属。Python 运行时来自 [python-build-standalone 20260814](https://github.com/astral-sh/python-build-standalone/releases/tag/20260814)。Windows Visual C++ 14.44 运行库采用微软的 [应用本地再分发条款](https://learn.microsoft.com/visualstudio/releases/2022/redistribution)，其余运行组件保留包内许可。
- CPU 推理使用 `ultralytics` 8.4.208。对应源码附件提供该版本以及 `ultralytics-platform` 0.1.108 和 `ultralytics-thop` 2.2.5 在 PyPI 发布的源码分发文件。GPU 路径使用 ONNX Runtime DirectML 1.24.4。[Ultralytics 源码](https://pypi.org/project/ultralytics/8.4.208/#files) · [ONNX Runtime 源码](https://github.com/microsoft/onnxruntime/tree/v1.24.4) · [DirectML](https://github.com/microsoft/DirectML)
- 原始 `bball_model.pt` 来自上游 BHE，随应用提供。动态批次 `bball_model.onnx` 由同一权重通过 `scripts/export_mobile_model.py --dynamic` 导出。源码附件同时提供原始权重及其校验值。原训练集和用户本机数据不随发行版提供。[模型来源及许可](MODEL_AND_DATA_LICENSES.md)
- 竖屏人物居中所用的 YOLOX-Nano 权重从上游官方 Release 单独下载。用户需要确认下载，后续构图、预览与导出均在本地运行。[人物模型来源及校验值](MODEL_AND_DATA_LICENSES.md#竖屏人物检测)

## 三个媒体组件

| 安装包内组件 | 许可与对应源码 |
| --- | --- |
| `libmpv-2.dll`，用于播放器 | 整个 DLL 为 LGPL-3.0-or-later。使用 freeKC 的 Windows x86-64 构建 `20261021-1`。第三方源码附件包含其完整对应源码归档和构建清单，安装目录的 `docs/libmpv-licenses/` 保存各组件许可。[freeKC 构建与源码](https://github.com/freeKC/libmpv-builds/releases/tag/20261021-1) |
| `runtime/bin/ffmpeg.exe` 与 `ffprobe.exe`，用于代理和导出 | BtbN `n8.1.3-34-ga35157abb9-20261109` 的 Windows x64 LGPL 静态构建，启用 `version3`。安装包附完整配置和许可。第三方源码附件包含 [FFmpeg 的准确源码](https://github.com/FFmpeg/FFmpeg/tree/a35157abb96167fd7308edc92b55408d5bb084b0) 和 [BtbN 的准确构建脚本、依赖版本与补丁](https://github.com/FFmpeg-Builds/FFmpeg-Builds/tree/c9fe5114060e507409f7ee07edfd82efaf25d767)。按 `win64 lgpl 8.1` 查看生成的构建阶段、静态依赖来源及取源命令。[运行记录](https://github.com/FFmpeg-Builds/FFmpeg-Builds/actions/runs/42614691088) · [上游关于恢复依赖源码的说明](https://github.com/FFmpeg-Builds/FFmpeg-Builds/issues/678#issuecomment-6085546673) |
| `opencv_videoio_ffmpeg500_64.dll`，由 OpenCV 读取视频时动态加载 | OpenCV 5.0.0 Windows 插件，保留 wheel 里的第三方许可。第三方源码附件包含该插件构建所用的 LGPL FFmpeg、依赖归档和构建脚本。[OpenCV 固定的二进制提交](https://github.com/opencv/opencv_3rdparty/tree/06dc20cad65dc7fcf784f70c95d46750520889a7) · [与该二进制对应的源码](https://github.com/opencv/opencv_3rdparty/tree/664c0098dcb47b361f20c1d6a518653c23f5f2b5) |

应用按文件路径加载播放器 DLL，并以独立进程运行 `ffmpeg` 和 `ffprobe`。用户可用自行构建的兼容组件替换安装目录中的对应文件。第三方源码附件提供另外下载，安装程序无需包含源码压缩包。
