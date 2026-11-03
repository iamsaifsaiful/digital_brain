// Screenshots are blocked only while a secret is on screen (owner, 31 Oct:
// "not every page"): the vault, a PIN pad, the will and the heirs' copy,
// health and medicines, documents and cards. Each such page is wrapped in
// [SecureView]; while at least one is open the window has FLAG_SECURE
// (MainActivity, channel "my_assistant/secure"), and when the last one
// closes it is taken off. A page under a secret one (pushed on top) stays
// blocked until the secret page itself is closed.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SecureScreens {
  static const _channel = MethodChannel('my_assistant/secure');
  static int _open = 0;

  /// How many secret pages are open now (for tests).
  static int get open => _open;

  static void enter() {
    if (_open++ == 0) _set(true);
  }

  static void leave() {
    if (_open == 0) return;
    if (--_open == 0) _set(false);
  }

  /// At start-up the window is blocked (MainActivity); unblock it unless a
  /// secret page (the lock screen) is already open.
  static void ready() {
    if (_open == 0) _set(false);
  }

  static void _set(bool on) {
    _channel.invokeMethod<void>('set', on).catchError((Object _) {});
  }
}

/// Blocks screenshots while [child] is on screen.
class SecureView extends StatefulWidget {
  const SecureView({super.key, required this.child});
  final Widget child;

  @override
  State<SecureView> createState() => _SecureViewState();
}

class _SecureViewState extends State<SecureView> {
  @override
  void initState() {
    super.initState();
    SecureScreens.enter();
  }

  @override
  void dispose() {
    SecureScreens.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
