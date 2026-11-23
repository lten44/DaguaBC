import 'package:desktop/features/settings/settings_dialog.dart';
import 'package:desktop/providers/project_state.dart';
import 'package:desktop/core/project_session.dart';
import 'package:desktop/core/engine_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('显示当前工程收集数量，读取失败时明确提示', (tester) async {
    SharedPreferences.setMockInitialValues({preferredProjectsRootPrefsKey: '/test/projects'});
    final transport = _LearningTransport();
    await tester.pumpWidget(ProviderScope(overrides: [
      projectSessionProvider.overrideWithValue(_LearningSession(EngineSession(transport))),
    ], child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => showDaguaSettingsDialog(context), child: const Text('设置')))))));
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已记录 3 次数据变更，起始快照 7 条'), findsOneWidget);
    transport.fail = true;
    await tester.ensureVisible(find.text('刷新记录数量'));
    await tester.tap(find.text('刷新记录数量'));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法读取学习记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清理前显示范围和工程保留提示，取消后不清理', (tester) async {
    SharedPreferences.setMockInitialValues({
      preferredProjectsRootPrefsKey: '/test/projects',
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDaguaSettingsDialog(context),
                child: const Text('设置'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('更改保存位置'), findsOneWidget);
    await tester.tap(find.text('清理缓存'));
    await tester.pumpAndSettle();
    expect(find.text('确认清理'), findsOneWidget);
    expect(find.textContaining('工程文件、审核记录、球员信息、原始视频和已导出视频会保留'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('确认清理'), findsNothing);
    expect(find.text('清理缓存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LearningSession extends ProjectSession {
  _LearningSession(super.engine);
  @override
  String? get projectRoot => '/test/projects/session';
}

class _LearningTransport implements EngineTransport {
  bool fail = false;
  @override
  Future<JsonMap> request(String command, JsonMap payload) async {
    if (command != 'get_learning_summary') throw StateError('Unexpected command $command');
    if (fail) throw StateError('fixture unavailable');
    return {'change_count': 3, 'baseline_count': 7, 'training_enabled': false};
  }
}
