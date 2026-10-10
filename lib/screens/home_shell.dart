import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'chat_home.dart';

/// The app's first page: the conversation (see [ChatHome]); every other
/// page opens from its menu.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) => const ChatHome();
}

/// Back to the conversation and start talking.
void openVoice(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  ChatHomeState.current?.startVoice();
}

/// Something typed on another page: back to the conversation, answered there.
void openChatWith(BuildContext context, String text) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  ChatHomeState.current?.send(text);
}

/// A page from the menu (আজ, হিসাব, আমি…), with a way back above its title.
class MenuPage extends StatelessWidget {
  const MenuPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 0, 0),
                child: IconButton(
                  tooltip: 'ফিরে যান',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left_rounded, size: 30, color: C.ink),
                ),
              ),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}
