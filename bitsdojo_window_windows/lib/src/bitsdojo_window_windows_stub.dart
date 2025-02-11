import 'dart:ui';

import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';
export './window_interface.dart';

class BitsdojoWindowWindows extends BitsdojoWindowPlatform {
  BitsdojoWindowWindows() {
    assert(false);
  }

  @override
  void doWhenWindowReady(VoidCallback callback) {}

  @override
  DesktopWindow get appWindow {
    return AppWindowNotImplemented();
  }
}
