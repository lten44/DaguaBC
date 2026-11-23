import 'package:desktop/features/about/about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('更新记录随软件资源发布并可打开', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showDaguaReleaseNotes(context), child: const Text('更新'))))));
    await tester.tap(find.text('更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.2.10 · 2026-11-15'), findsOneWidget);
    expect(find.textContaining('当前不自动训练'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
