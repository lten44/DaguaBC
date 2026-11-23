import 'package:desktop/features/review/source_review_timeline.dart';
import 'package:desktop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final position in [0, 50000, 100000]) {
    testWidgets('playhead stays visible and allows marker selection at $position', (tester) async {
      int? seek;
      String? selected;
      await tester.pumpWidget(MaterialApp(theme: appTheme(Brightness.dark),
        home: Scaffold(body: SourceReviewTimeline(durationMs: 100000, positionMs: position,
          candidates: [
            {'id': 'at-cursor', 'event_time_ms': position, 'review_status': 'goal'},
          ], onSeek: (ms) => seek = ms, onSelectCandidate: (id) => selected = id))));
      final track = tester.getRect(find.byKey(const Key('source-timeline-track')));
      final stem = tester.getRect(find.byKey(const Key('source-playhead-stem')));
      expect(stem.center.dx, closeTo(track.left + track.width * position / 100000, .001));
      expect(stem.intersect(track).width, greaterThanOrEqualTo(2));
      expect(stem.height, greaterThan(24));
      // A wide, glowing overlay must not block selecting the marker beneath it.
      await tester.tapAt(Offset(stem.center.dx.clamp(track.left + 1, track.right - 1), track.top + 20));
      expect(seek, position);
      expect(selected, 'at-cursor');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('clicking a crowded marker lets user pick its exact candidate', (tester) async {
    String? selected;
    int? seek;
    await tester.pumpWidget(MaterialApp(theme: appTheme(Brightness.dark),
      home: Scaffold(body: SourceReviewTimeline(durationMs: 600000, positionMs: 0,
        candidates: const [
          {'id': 'one', 'event_time_ms': 300000, 'review_status': 'goal'},
          {'id': 'two', 'event_time_ms': 301000, 'review_status': 'pending'},
        ], onSeek: (ms) => seek = ms, onSelectCandidate: (id) => selected = id))));
    await tester.tapAt(tester.getCenter(find.byTooltip('5:00 · 通过')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('5:01 · 候选 2 · 未确认'));
    await tester.pumpAndSettle();
    expect(seek, 301000);
    expect(selected, 'two');
  });

  testWidgets('clicking covered footage selects the row without changing requested time', (tester) async {
    String? selected;
    int? seek;
    await tester.pumpWidget(MaterialApp(theme: appTheme(Brightness.dark),
      home: Scaffold(body: SourceReviewTimeline(durationMs: 100000, positionMs: 0,
        candidates: const [
          {'id': 'one', 'event_time_ms': 30000, 'clip_start_ms': 20000, 'clip_end_ms': 40000},
        ], onSeek: (ms) => seek = ms, onSelectCandidate: (id) => selected = id))));
    final track = tester.getRect(find.byKey(const Key('source-timeline-track')));
    await tester.tapAt(Offset(track.left + track.width * .25, track.top + 15));
    expect(seek, 25000);
    expect(selected, 'one');
    selected = null;
    await tester.tapAt(Offset(track.left + track.width * .8, track.top + 15));
    expect(seek, 80000);
    expect(selected, isNull);
  });

  test('human decisions override model uncertainty and undo restores it', () {
    final candidate = <String, dynamic>{
      'review_status': 'pending',
      'evidence': {'rim_check': {'status': 'unsure'}},
    };
    expect(effectiveRimStatus(candidate), 'unsure');
    expect(effectiveRimStatus({...candidate, 'review_status': 'goal'}), 'made');
    expect(effectiveRimStatus({...candidate, 'review_status': 'excluded'}), 'rejected');
    expect(effectiveRimStatus(candidate), 'unsure');
  });

  testWidgets('zoom, pan and seek retain distinct nearby goal markers', (tester) async {
    int? seek;
    await tester.pumpWidget(MaterialApp(theme: appTheme(Brightness.dark),
      home: Scaffold(body: SourceReviewTimeline(durationMs: 600000, positionMs: 300000,
        candidates: const [
          {'event_time_ms': 300000, 'clip_start_ms': 295000, 'clip_end_ms': 304000, 'review_status': 'goal'},
          {'event_time_ms': 305000, 'clip_start_ms': 301000, 'clip_end_ms': 309000, 'review_status': 'pending'},
          {'event_time_ms': 10000, 'review_status': 'excluded'},
        ], onSeek: (ms) => seek = ms))));
    expect(find.byTooltip('5:00 · 通过'), findsOneWidget);
    expect(find.byTooltip('5:05 · 未确认'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('放大时间轴'));
      await tester.pump();
    }
    expect(find.text('16×'), findsOneWidget);
    expect(find.byTooltip('0:10 · 排除'), findsNothing);
    final marker = tester.getCenter(find.byTooltip('5:05 · 未确认'));
    await tester.tapAt(marker);
    expect(seek, 305000);
    await tester.tap(find.byTooltip('前一段'));
    await tester.pump();
    expect(find.byTooltip('5:00 · 通过'), findsNothing);
    await tester.tap(find.text('当前位置'));
    await tester.pump();
    expect(find.byTooltip('5:00 · 通过'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
