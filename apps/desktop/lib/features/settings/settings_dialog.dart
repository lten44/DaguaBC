import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/project_state.dart';

Future<void> showDaguaSettingsDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _SettingsDialog(),
);

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  String? _root;
  String? _message;
  bool _working = false;
  Map<String, dynamic>? _learning;
  String? _learningError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final root = await ref
          .read(projectProvider.notifier)
          .projectStorageDirectory();
      if (mounted) setState(() => _root = root);
    } catch (error) {
      if (mounted) setState(() => _message = '无法读取保存位置：$error');
    }
    await _loadLearning();
  }

  Future<void> _loadLearning() async {
    final session = ref.read(projectSessionProvider);
    final root = session.projectRoot;
    if (root == null) return;
    try {
      await ref.read(projectProvider.notifier).flushReviewQueue();
      final summary = await session.engine.getLearningSummary(projectRoot: root);
      if (mounted) setState(() { _learning = summary; _learningError = null; });
    } catch (error) {
      if (mounted) setState(() => _learningError = '无法读取学习记录：$error');
    }
  }

  Future<void> _changeDirectory() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final root = await getDirectoryPath(
        initialDirectory: _root,
        confirmButtonText: '选择保存位置',
      );
      if (!mounted || root == null) return;
      await ref.read(projectProvider.notifier).setProjectStorageDirectory(root);
      if (mounted) {
        setState(() {
          _root = root;
          _message = '保存位置已更新。新项目使用此目录，已有项目仍保留在原处。';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = '未能更改保存位置：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存？'),
        content: Text(
          '清理以下目录内所有项目的代理、分析和预览缓存：\n$_root\n\n'
          '工程文件、审核记录、球员信息、原始视频和已导出视频会保留。'
          '下次预览或分析时可能需要重新生成缓存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final count = await ref
          .read(projectProvider.notifier)
          .cleanupProjectCaches(root: _root!);
      if (mounted) {
        setState(
          () => _message = count == null
              ? '清理未完成，请查看错误提示。工程文件会保留。'
              : count == 0
              ? '此目录中没有可清理的项目缓存。'
              : '已清理 $count 个项目的缓存，工程和导出视频已保留。',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = '未能清理缓存：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final busy =
        _working ||
        project.busy ||
        project.analysisRunning ||
        project.exportRunning;
    return PopScope(
      canPop: !_working,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.settings, size: 22),
            SizedBox(width: 10),
            Text('设置'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('项目与缓存', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text('保存位置'),
                const SizedBox(height: 8),
                SelectableText(_root ?? '正在读取…'),
                const SizedBox(height: 12),
                const Text(
                  '工程文件、分析缓存和预览文件保存在项目文件夹中。更改位置仅影响新项目，已有项目仍可从“最近项目”打开。',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy || _root == null ? null : _changeDirectory,
                  icon: const Icon(LucideIcons.folderOpen, size: 18),
                  label: const Text('更改保存位置'),
                ),
                const Divider(height: 32),
                const Text('清理缓存会保留工程和已导出视频，之后可能需要重新生成预览或分析缓存。'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy || _root == null ? null : _clearCache,
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  label: const Text('清理缓存'),
                ),
                const Divider(height: 32),
                Text('学习样本收集', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('自动在工程中记录补漏、审核、片段范围、球员标签和篮筐等修改。记录仅保存在本机，清理缓存会保留；删除工程会一并删除记录。'),
                const SizedBox(height: 8),
                const Text('当前只收集记录，不会自动训练。保留或排除片段不直接作为进球或没进的训练答案。'),
                const SizedBox(height: 8),
                Text(_learningError ?? (_learning == null
                    ? '打开项目后可查看该工程的收集情况。'
                    : '当前工程：已记录 ${_learning!['change_count']} 次数据变更，起始快照 ${_learning!['baseline_count']} 条。'),
                  key: const Key('learning-record-summary')),
                if (_learning != null || _learningError != null)
                  TextButton(onPressed: busy ? null : _loadLearning, child: const Text('刷新记录数量')),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('请等待当前操作、分析或导出结束。'),
                  ),
                if (_working)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_message!),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _working ? null : () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
