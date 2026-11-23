// test/components/cs_notice_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:desktop/components/cs_notice.dart';
import 'package:desktop/components/cs_notice_overlay.dart';
import 'package:desktop/providers/notice_provider.dart';
import 'package:desktop/theme/app_theme.dart';

void main() {
  testWidgets('success notice shows title icon and close, tap dismisses',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Center(
          child: CsNotice(
            message: const NoticeMessage(
              id: '1',
              severity: NoticeSeverity.success,
              title: '保存成功',
            ),
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('保存成功'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.x));
    expect(dismissed, isTrue);
  });

  testWidgets('error notices keep their message without a feedback action', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(noticeProvider.notifier).push(const NoticeMessage(
      id: 'read-error',
      severity: NoticeSeverity.error,
      title: '项目读取失败',
      description: '请检查工程目录',
    ));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appTheme(Brightness.dark),
        home: const CsNoticeOverlay(child: Scaffold()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('项目读取失败'), findsOneWidget);
    expect(find.text('请检查工程目录'), findsOneWidget);
    expect(find.text('反馈这个问题'), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('项目读取失败'), findsNothing);
  });
}
