import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:bhe_l10n/bhe_l10n.dart';

import '../../core/engine_client.dart';
import '../../core/engine_session.dart';

class PortraitTrialDialog extends StatefulWidget {
  const PortraitTrialDialog({
    super.key,
    required this.engine,
    required this.projectRoot,
    this.playerIds,
    this.includeUnassigned,
  });

  final EngineSession engine;
  final String projectRoot;
  final List<String>? playerIds;
  final bool? includeUnassigned;

  @override
  State<PortraitTrialDialog> createState() => _PortraitTrialDialogState();
}

class _PortraitTrialDialogState extends State<PortraitTrialDialog> {
  List<JsonMap> _clips = [];
  final Map<String, JsonMap> _plans = {};
  JsonMap? _selected;
  JsonMap? _frame;
  int _time = 0;
  bool _preparing = true;
  bool _working = false;
  bool _needsModel = false;
  String? _error;

  String _id(JsonMap clip) => clip['id'] as String;
  int _event(JsonMap clip) => clip['event_time_ms'] as int;
  int _start(JsonMap clip) => clip['review_start_ms'] as int;
  int _end(JsonMap clip) => clip['review_end_ms'] as int;
  String? _status(JsonMap clip) => _plans[_id(clip)]?['status'] as String?;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<JsonMap> _request(String command, [JsonMap data = const {}]) =>
      widget.engine.client.request('portrait_trial_$command', {
        'project_root': widget.projectRoot,
        ...data,
      });

  Future<void> _prepare({bool downloadModel = false}) async {
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      final result = await _request('list', {
        if (widget.playerIds != null) 'player_ids': widget.playerIds,
        if (widget.includeUnassigned != null)
          'include_unassigned': widget.includeUnassigned,
      });
      if (!mounted) return;
      final clips = (result['clips'] as List).cast<JsonMap>();
      setState(() => _clips = clips);
      for (final clip in clips) {
        final plan = await _request('prepare', {
          'candidate_id': _id(clip),
          if (downloadModel) 'download_person_model': true,
        });
        if (!mounted) return;
        setState(() => _plans[_id(clip)] = plan);
      }
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _needsModel = false;
      });
      if (clips.isNotEmpty) {
        await _inspect(clips.firstWhere(
          (clip) => _status(clip) == 'pending',
          orElse: () => clips.first,
        ));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _needsModel = error is EngineException &&
            {'PORTRAIT_MODEL_MISSING', 'PORTRAIT_MODEL_DOWNLOAD'}.contains(error.code);
        _error = error is EngineException ? error.message : error.toString();
      });
    }
  }

  Future<void> _inspect(JsonMap clip) async {
    if (_working || _preparing) return;
    final plan = _plans[_id(clip)];
    if (plan == null) return;
    setState(() {
      _selected = clip;
      _time = (plan['release_ms'] as int).clamp(_start(clip), _end(clip) - 1);
      _frame = null;
    });
    await _loadFrame();
  }

  Future<void> _loadFrame() async {
    final clip = _selected;
    if (clip == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final result = await _request('frame', {
        'candidate_id': _id(clip),
        'time_ms': _time,
      });
      if (mounted) setState(() => _frame = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _decide(String choice, [Offset? point]) async {
    final clip = _selected;
    if (clip == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final result = await _request('decide', {
        'candidate_id': _id(clip),
        'choice': choice,
        if (point != null) ...{'time_ms': _time, 'x': point.dx, 'y': point.dy},
      });
      if (mounted) setState(() => _plans[_id(clip)] = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return;
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (mounted) await _loadFrame();
  }

  String _label(String? status) => switch (status) {
    'auto' => '自动找到',
    'manual' => '已点选',
    'ball' => '沿用跟球',
    'pending' => '待点选',
    _ => '待处理',
  };

  String _clock(int ms) {
    final seconds = ms ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}.${ms % 1000 ~/ 100}';
  }

  void _advance() {
    final index = _clips.indexOf(_selected!);
    final remaining = [..._clips.skip(index + 1), ..._clips.take(index)];
    final pending = remaining.where((clip) => _status(clip) == 'pending');
    if (pending.isNotEmpty) _inspect(pending.first);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _clips.where((clip) => _status(clip) == 'pending').length;
    final finished = !_preparing && _clips.isNotEmpty &&
        _plans.length == _clips.length && pending == 0;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(context.bheText('竖屏构图 · 人物居中')),
      content: SizedBox(
        width: 960,
        height: 510,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_preparing
                ? '正在查找出手人  ${_plans.length} / ${_clips.length}'
                : '共 ${_clips.length} 个片段 · ${_plans.values.where((plan) => plan['status'] == 'auto').length} 个自动找到 · $pending 个待点选'),
            if (_preparing) const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SelectableText(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 207,
                    child: ListView.builder(
                      itemCount: _clips.length,
                      itemBuilder: (context, index) {
                        final clip = _clips[index];
                        final player = clip['player_name'] as String?;
                        return ListTile(
                          dense: true,
                          selected: _selected == clip,
                          title: Text('${_clock(_event(clip))}${player == null ? '' : '  $player'}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_label(_status(clip))),
                          onTap: _preparing || _working ? null : () => _inspect(clip),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInspector()),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回')),
        if (!_preparing && _needsModel)
          TextButton(
            onPressed: () => _prepare(downloadModel: true),
            child: Text(context.bheText('下载人物模型（约 3.7 MB）')),
          )
        else if (!_preparing && _plans.length < _clips.length)
          TextButton(onPressed: _prepare, child: const Text('重试准备')),
        FilledButton(
          onPressed: finished && !_working ? () => Navigator.pop(context, true) : null,
          child: const Text('确认构图并继续导出'),
        ),
      ],
    );
  }

  Widget _buildInspector() {
    final clip = _selected;
    if (clip == null) return const SizedBox.shrink();
    final frame = _frame;
    final canClick = !_working && frame?['time_ms'] == _time;
    final low = _start(clip);
    final high = math.max(low+1, _end(clip)-1);
    final next = _clips.any((other) => other != clip && _status(other) == 'pending');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('拖到出手那一刻，在左图点球员上半身，右侧预览竖屏构图。'),
        const SizedBox(height: 8),
        Expanded(
          child: frame == null
              ? Center(child: _working ? const CircularProgressIndicator() : const Text('暂无预览'))
              : Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: (frame['aspect'] as num).toDouble(),
                        child: _CropPreview(frame: frame, cropped: false,
                          onSelect: canClick ? (point) => _decide('manual',point) : null),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(child: AspectRatio(aspectRatio: 9/16,
                      child: _CropPreview(frame: frame, cropped: true))),
                  ),
                ],
              ),
        ),
        Slider(
          value: _time.clamp(low,high).toDouble(), min: low.toDouble(), max: high.toDouble(),
          onChanged: _working ? null : (value) => setState(() => _time = value.round()),
          onChangeEnd: _working ? null : (_) => _loadFrame(),
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${_clock(_time)}  ·  ${_label(_status(clip))}'),
            TextButton(onPressed: _working ? null : () => _decide('ball'),
                child: const Text('这一球沿用跟球')),
            TextButton(onPressed: _working || !next ? null : _advance,
                child: const Text('下一条待点选')),
          ],
        ),
      ],
    );
  }
}

class _CropPreview extends StatelessWidget {
  const _CropPreview({required this.frame, required this.cropped, this.onSelect});

  final JsonMap frame;
  final bool cropped;
  final void Function(Offset)? onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final w = bounds.maxWidth;
      final h = bounds.maxHeight;
      final left = (frame['left'] as num).toDouble();
      final top = (frame['top'] as num).toDouble();
      final width = (frame['width'] as num).toDouble();
      final height = (frame['height'] as num).toDouble();
      final picture = Image.file(File(frame['path'] as String), fit: BoxFit.fill,
          gaplessPlayback: true, errorBuilder: (_, _, _) => const Center(child: Text('画面加载失败')));
      if (cropped) {
        return Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(left: -left*w/width, top: -top*h/height,
              width: w/width, height: h/height, child: picture),
        ]);
      }
      return MouseRegion(
        cursor: onSelect == null ? MouseCursor.defer : SystemMouseCursors.precise,
        child: GestureDetector(
          onTapDown: onSelect == null ? null : (details) {
            onSelect!(Offset((details.localPosition.dx/w).clamp(0,1),
                             (details.localPosition.dy/h).clamp(0,1)));
          },
          child: Stack(fit: StackFit.expand, children: [
            picture,
            Positioned(left: left*w, top: top*h, width: width*w, height: height*h,
              child: DecoratedBox(decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
              )),
            ),
          ]),
        ),
      );
    },
  );
}
