# 模型来源与使用范围

DaguaBC 的桌面检测模型来自 Jafir 和 BHE 贡献者维护的 Basketball Highlight Editor。原始文件位于上游基线提交的 `models/bball_model.pt`。下列校验值用于与该版本对照。[上游权重文件](https://github.com/fly7632785/basketball-highlight-editor/blob/0472b95072c7cdd4fe3864b1a1288e27ab5ee379/models/bball_model.pt)

| 文件 | SHA-256 |
| --- | --- |
| `bball_model.pt` | `40f3e596652a427ba290b3f72384e49aed12caf1a8ae41beaef4a8fffcf09fa3` |

2026 年 11 月 23 日，上游维护者 @fly7632785 对公开 Fork 和 Windows 包的模型再分发询问作出肯定答复，并说明 `bball_model` 是开源模型。该询问也提到了 ONNX 派生权重和训练数据，回复未单独列出 ONNX 条款、训练集来源或训练数据许可。已检查的原始权重元数据标注 `AGPL-3.0 (https://ultralytics.com/license)`。应用源码、模型和依赖分别适用各自的许可。[作者回复](https://github.com/fly7632785/basketball-highlight-editor/issues/21#issuecomment-7090238591) · [Ultralytics 许可](https://www.ultralytics.com/license)

Windows 对应源码归档含有桌面代码、原始权重和模型转换脚本。使用其他源码检出时，可从上述上游提交获取对应权重，经校验后放到本地 `models/`。Windows DirectML 使用同一权重导出的动态批量 ONNX。训练集、比赛视频、球员图像、人工标注、审核记录及本机项目不随归档分发。[Windows 源码运行](WINDOWS_SOURCE.md) · [安装包与对应源码](WINDOWS_DISTRIBUTION.md)
