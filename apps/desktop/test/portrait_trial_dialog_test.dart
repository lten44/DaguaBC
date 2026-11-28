import 'dart:convert';
import 'dart:io';

import 'package:desktop/core/engine_session.dart';
import 'package:desktop/features/export/portrait_trial_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a pending shooter must be resolved before export', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final folder = Directory.systemTemp.createTempSync('portrait-trial-test');
    final frame = File('${folder.path}/frame.png')..writeAsBytesSync(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZk8AAAAASUVORK5CYII=',
    ));
    addTearDown(() {
      frame.deleteSync();
      folder.deleteSync();
    });
    final transport = _TrialTransport(frame.path);
    bool? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          result = await showDialog<bool>(context: context, builder: (_) =>
            PortraitTrialDialog(engine: EngineSession(transport), projectRoot: 'test',
                playerIds: const ['player-a'], includeUnassigned: false));
        },
        child: const Text('打开'),
      );
    }))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, '确认构图并继续导出');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(transport.selection?['player_ids'], ['player-a']);
    expect(transport.selection?['include_unassigned'], false);
    expect(find.text('待点选'), findsOneWidget);
    final sourceFrame = find.byWidgetPredicate(
        (widget) => widget is MouseRegion && widget.cursor == SystemMouseCursors.precise);
    final rectangle = tester.getRect(sourceFrame);
    await tester.tapAt(Offset(rectangle.left + rectangle.width * .75, rectangle.center.dy));
    await tester.pumpAndSettle();
    expect(transport.decided?['candidate_id'], 'manual-clip');
    expect(transport.decided?['x'], closeTo(.75, .01));
    expect(transport.decided?['time_ms'], 2100);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, true);
  });
}

class _TrialTransport implements EngineTransport {
  _TrialTransport(this.framePath);

  final String framePath;
  JsonMap? selection;
  JsonMap? decided;

  @override
  Future<JsonMap> request(String command, JsonMap payload) async {
    switch (command) {
      case 'portrait_trial_list':
        selection = payload;
        return {'clips': <JsonMap>[
          {'id': 'auto-clip', 'event_time_ms': 3000, 'review_start_ms': 0, 'review_end_ms': 4500},
          {'id': 'manual-clip', 'event_time_ms': 3000, 'review_start_ms': 0, 'review_end_ms': 4500},
        ]};
      case 'portrait_trial_prepare':
        return {'status': payload['candidate_id'] == 'manual-clip' ? 'pending' : 'auto',
                'release_ms': 2100};
      case 'portrait_trial_frame':
        return {'path': framePath, 'time_ms': payload['time_ms'], 'aspect': 16/9,
                'left': decided == null ? .30 : .592, 'top': 0, 'width': .316, 'height': 1};
      case 'portrait_trial_decide':
        decided = payload;
        return {'status': 'manual', 'release_ms': 2100};
    }
    throw StateError(command);
  }
}
