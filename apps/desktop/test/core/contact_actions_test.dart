import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/core/contact_actions.dart';

void main() {
  test('Windows passes an external link as a single argument', () {
    const url = 'https://update.example/download?version=1.0&arch=x64';
    final windows = externalOpenCommand(url, platform: 'windows');
    expect(windows.executable, 'rundll32');
    expect(windows.arguments, ['url.dll,FileProtocolHandler', url]);
  });

  test('macOS and Linux keep their own openers', () {
    expect(
      externalOpenCommand('https://x.example', platform: 'macos').executable,
      'open',
    );
    expect(
      externalOpenCommand('https://x.example', platform: 'linux').executable,
      'xdg-open',
    );
  });
}
