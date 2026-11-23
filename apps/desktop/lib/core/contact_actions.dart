import 'dart:io';

/// Windows 直接交给系统处理链接，避免 cmd 把查询参数中的 `&` 当成命令分隔符。
({String executable, List<String> arguments}) externalOpenCommand(
  String uri, {
  required String platform,
}) => switch (platform) {
  'macos' => (executable: 'open', arguments: <String>[uri]),
  'windows' => (
    executable: 'rundll32',
    arguments: <String>['url.dll,FileProtocolHandler', uri],
  ),
  _ => (executable: 'xdg-open', arguments: <String>[uri]),
};

Future<bool> openExternalUri(String uri) async {
  final command = externalOpenCommand(uri, platform: Platform.operatingSystem);
  final result = await Process.run(command.executable, command.arguments);
  return result.exitCode == 0;
}
