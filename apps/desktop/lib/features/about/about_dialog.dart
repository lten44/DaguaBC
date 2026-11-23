import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/diagnostics.dart';

Future<void> showCourtsideAboutDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AboutDialog(
    applicationName: 'DaguaBC',
    applicationVersion: '大瓜篮球剪辑 · $appVersion',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/brand/dagua-icon.png', width: 64, height: 64),
    ),
    children: [
      const Text('固定机位 · 单篮筐 · 本地处理\n自动寻找候选，人工排除与补漏。'),
      TextButton(onPressed: () => showDaguaReleaseNotes(context), child: const Text('版本更新记录')),
      const SizedBox(height: 16),
      const Text('基于开源 basketball-highlight-editor（BHE）构建。\nCopyright 2026 BHE contributors · MIT License\n第三方模型与运行组件保留各自许可。'),
    ],
  ),
);

Future<void> showDaguaReleaseNotes(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('版本更新记录'),
    content: SizedBox(width: 560, child: SingleChildScrollView(
      child: FutureBuilder<String>(
        future: rootBundle.loadString('assets/release_notes.md'),
        builder: (context, snapshot) => SelectableText(snapshot.hasError
            ? '更新记录读取失败，请重新打开此窗口。'
            : snapshot.data ?? '正在读取…'),
      ),
    )),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
  ),
);
