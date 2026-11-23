import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Human decisions take precedence over the original model result.
String? effectiveRimStatus(Map<String, dynamic> candidate, {String? modelStatus}) {
  final status = candidate['review_status'];
  if (status == 'goal') return 'made';
  if (status == 'excluded') return 'rejected';
  final evidence = candidate['evidence'];
  final decoded = evidence is Map ? evidence['rim_check'] : null;
  return modelStatus ?? (decoded is Map ? decoded['status']?.toString() : null);
}

class SourceReviewTimeline extends StatefulWidget {
  const SourceReviewTimeline({super.key, required this.durationMs,
    required this.positionMs, required this.candidates, required this.onSeek,
    this.onSelectCandidate, this.selectedCandidateId, this.enabled = true});
  final int durationMs;
  final int positionMs;
  final List<Map<String, dynamic>> candidates;
  final ValueChanged<int> onSeek;
  final bool enabled;
  final ValueChanged<String>? onSelectCandidate;
  final String? selectedCandidateId;

  @override
  State<SourceReviewTimeline> createState() => _SourceReviewTimelineState();
}

class _SourceReviewTimelineState extends State<SourceReviewTimeline> {
  int _zoom = 1;
  double _start = 0;
  double get _duration => math.max(1, widget.durationMs).toDouble();
  double get _span => math.max(1000.0, _duration / _zoom).clamp(1.0, _duration);
  double get _left => _start.clamp(0, _duration - _span);
  String _time(num ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  void _changeZoom(int zoom) => setState(() {
    final center = widget.positionMs.clamp(_left, _left + _span).toDouble();
    _zoom = zoom.clamp(1, 256);
    _start = (center - _span / 2).clamp(0, _duration - _span);
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: c.textSecondary);
    final left = _left;
    final span = _span;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text('补漏时间轴', style: style),
        const SizedBox(width: 8),
        Expanded(child: Text('绿：通过  橙：未确认  灰：排除', style: style,
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(tooltip: '缩小时间轴', onPressed: _zoom > 1 ? () => _changeZoom(_zoom ~/ 2) : null,
          icon: const Icon(Icons.remove, size: 16), constraints: const BoxConstraints.tightFor(width: 28, height: 28), padding: EdgeInsets.zero),
        Text('$_zoom×', style: style),
        IconButton(tooltip: '放大时间轴', onPressed: _zoom < 256 ? () => _changeZoom(_zoom * 2) : null,
          icon: const Icon(Icons.add, size: 16), constraints: const BoxConstraints.tightFor(width: 28, height: 28), padding: EdgeInsets.zero),
        TextButton(onPressed: () => setState(() => _start = (widget.positionMs - span / 2).clamp(0, _duration - span)),
          child: Text('当前位置', style: style)),
      ]),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        double x(num ms) => ((ms - left) / span * width).clamp(0, width);
        Future<void> seek(double dx, {bool select = false}) async {
          if (!widget.enabled) return;
          var ms = (left + dx.clamp(0, width) / width * span).round();
          // Snap only to nearby event markers, never merge adjacent events.
          double nearest = 7;
          Map<String, dynamic>? chosen;
          final hits = <Map<String, dynamic>>[];
          for (final candidate in widget.candidates) {
            final event = (candidate['event_time_ms'] as num?)?.toInt();
            if (event == null || event < left || event > left + span) continue;
            final distance = (x(event) - dx).abs();
            if (distance < 7) hits.add(candidate);
            if (distance < nearest) { nearest = distance; ms = event; chosen = candidate; }
          }
          if (select && hits.length > 1 && widget.onSelectCandidate != null) {
            final box = context.findRenderObject()! as RenderBox;
            final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
            final point = box.localToGlobal(Offset(dx, 0), ancestor: overlay);
            final id = await showMenu<String>(context: context,
              position: RelativeRect.fromRect(Rect.fromLTWH(point.dx, point.dy, 1, 1), Offset.zero & overlay.size),
              items: [for (final candidate in hits)
                PopupMenuItem(value: candidate['id']?.toString(), child: Text(
                  '${_time(candidate['event_time_ms'] as num)} · 候选 ${widget.candidates.indexOf(candidate) + 1} · ${effectiveRimStatus(candidate) == 'made' ? '通过' : effectiveRimStatus(candidate) == 'rejected' ? '排除' : '未确认'}'))]);
            if (!mounted || id == null) return;
            chosen = hits.firstWhere((candidate) => candidate['id']?.toString() == id);
            ms = (chosen['event_time_ms'] as num).round();
          }
          if (select && chosen == null) {
            final covering = widget.candidates.where((candidate) =>
                (candidate['clip_start_ms'] as num? ?? -1) <= ms &&
                (candidate['clip_end_ms'] as num? ?? -1) >= ms).toList()
              ..sort((a, b) => ((a['event_time_ms'] as num) - ms).abs().compareTo(((b['event_time_ms'] as num) - ms).abs()));
            if (covering.isNotEmpty) chosen = covering.first;
          }
          widget.onSeek(ms.clamp(0, widget.durationMs));
          if (select && chosen?['id'] != null) widget.onSelectCandidate?.call(chosen!['id'].toString());
        }
        return GestureDetector(
          key: const Key('source-timeline-track'),
          onTapUp: (event) => seek(event.localPosition.dx, select: true),
          onHorizontalDragUpdate: (event) => seek(event.localPosition.dx),
          child: MouseRegion(cursor: SystemMouseCursors.click, child: SizedBox(
            height: 50, width: double.infinity,
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(left: 0, right: 0, top: 14, height: 15,
                child: ColoredBox(color: c.surface3)),
              for (final candidate in widget.candidates)
                if ((candidate['clip_end_ms'] as num? ?? candidate['event_time_ms'] as num? ?? 0) >= left &&
                    (candidate['clip_start_ms'] as num? ?? candidate['event_time_ms'] as num? ?? 0) <= left + span)
                  Positioned(
                    left: x(candidate['clip_start_ms'] as num? ?? candidate['event_time_ms'] as num? ?? 0), top: 14, height: 15,
                    width: math.max(2, x(candidate['clip_end_ms'] as num? ?? candidate['event_time_ms'] as num? ?? 0) - x(candidate['clip_start_ms'] as num? ?? candidate['event_time_ms'] as num? ?? 0)),
                    child: ColoredBox(color: c.orange.withValues(alpha: .18))),
              for (final candidate in widget.candidates)
                if ((candidate['event_time_ms'] as num? ?? -1) >= left && (candidate['event_time_ms'] as num? ?? -1) <= left + span)
                  Positioned(left: x(candidate['event_time_ms'] as num) - 1, top: 7,
                    width: candidate['id'] == widget.selectedCandidateId ? 5 : 3, height: 24,
                    child: Tooltip(message: '${_time(candidate['event_time_ms'] as num)} · ${effectiveRimStatus(candidate) == 'made' ? '通过' : effectiveRimStatus(candidate) == 'rejected' ? '排除' : '未确认'}',
                      child: ColoredBox(color: effectiveRimStatus(candidate) == 'made' ? c.success : effectiveRimStatus(candidate) == 'rejected' ? c.textTertiary : c.warning))),
              if (widget.positionMs >= left && widget.positionMs <= left + span)
                Positioned(
                  left: x(widget.positionMs) - 8, top: 0, width: 16, height: 36,
                  child: IgnorePointer(
                    child: Semantics(
                      label: '当前播放位置 ${_time(widget.positionMs)}',
                      child: Stack(children: [
                        Positioned(left: 6, top: 4, bottom: 0, width: 4,
                          child: DecoratedBox(
                            key: const Key('source-playhead-stem'),
                            decoration: BoxDecoration(
                              color: c.orange,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [BoxShadow(color: c.orange.withValues(alpha: .55), blurRadius: 6, spreadRadius: 1)],
                            ),
                          )),
                        Positioned(left: 2, top: 0, width: 12, height: 8,
                          child: DecoratedBox(
                            key: const Key('source-playhead-cap'),
                            decoration: BoxDecoration(
                              color: c.orange,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [BoxShadow(color: c.orange.withValues(alpha: .4), blurRadius: 6)],
                            ),
                          )),
                      ]),
                    ),
                  ),
                ),
              Positioned(left: 0, bottom: 0, child: Text(_time(left), style: style)),
              Positioned(right: 0, bottom: 0, child: Text(_time(left + span), style: style)),
            ]),
          )),
        );
      }),
      if (_zoom > 1)
        Row(children: [
          IconButton(tooltip: '前一段', onPressed: () => setState(() => _start = (left - span).clamp(0, _duration - span)), icon: const Icon(Icons.chevron_left, size: 18)),
          Expanded(child: Slider(key: const Key('source-timeline-pan'), min: 0, max: _duration - span,
            value: left, onChanged: (value) => setState(() => _start = value))),
          IconButton(tooltip: '后一段', onPressed: () => setState(() => _start = (left + span).clamp(0, _duration - span)), icon: const Icon(Icons.chevron_right, size: 18)),
        ]),
    ]);
  }
}
