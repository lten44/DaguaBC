import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Windows native EDIT supplies its own IME session instead of reusing the
/// Flutter view's input context. Cancellation returns null; failures propagate.
class NativeTextInput {
  static const channel = MethodChannel('daguabc/native_text_input');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<String?> prompt({
    required String title,
    required String hint,
    required String confirmLabel,
    required String cancelLabel,
    String initialText = '',
    bool dark = true,
  }) => channel.invokeMethod<String>('prompt', {
    'title': title,
    'hint': hint,
    'initialText': initialText,
    'confirmLabel': confirmLabel,
    'cancelLabel': cancelLabel,
    'dark': dark,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmLabel,
    required String cancelLabel,
    String initialText = '',
  }) async {
    String? value;
    Object? failure;
    StackTrace? failureStack;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SystemInputHost(
        open: () async {
          try {
            value = await prompt(
              title: title,
              hint: hint,
              confirmLabel: confirmLabel,
              cancelLabel: cancelLabel,
              initialText: initialText,
              dark: Theme.of(context).brightness == Brightness.dark,
            );
          } catch (error, stack) {
            failure = error;
            failureStack = stack;
          } finally {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          }
        },
      ),
    );
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    return value;
  }
}

class _SystemInputHost extends StatefulWidget {
  const _SystemInputHost({required this.open});
  final Future<void> Function() open;

  @override
  State<_SystemInputHost> createState() => _SystemInputHostState();
}

class _SystemInputHostState extends State<_SystemInputHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open();
    });
  }

  @override
  Widget build(BuildContext context) => const PopScope(
    canPop: false,
    child: SizedBox.shrink(),
  );
}
