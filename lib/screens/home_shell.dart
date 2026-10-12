import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'chat_home.dart';
import 'diary_screen.dart';
import 'home_page.dart';
import 'ledger_screen.dart';
import 'store_screen.dart';

/// হোম · দিনলিপি · (সহকারী) · হিসাব · সংরক্ষণ — an organiser with the
/// assistant always one tap away in the middle.
enum ShellTab { home, diary, money, store }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  /// The open shell, so a page can switch tabs ([goToTab]).
  static HomeShellState? current;

  ShellTab _tab = ShellTab.home;
  final _money = GlobalKey<MoneyScreenState>();

  @override
  void initState() {
    super.initState();
    current = this;
  }

  @override
  void dispose() {
    if (current == this) current = null;
    super.dispose();
  }

  void go(ShellTab t, {MoneyPart? money}) {
    setState(() => _tab = t);
    if (money != null) WidgetsBinding.instance.addPostFrameCallback((_) => _money.currentState?.show(money));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == ShellTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(ShellTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            const HomePage(),
            const SafeArea(bottom: false, child: DiaryScreen()),
            SafeArea(bottom: false, child: MoneyScreen(key: _money)),
            const SafeArea(bottom: false, child: StoreScreen()),
          ],
        ),
        bottomNavigationBar: _Nav(current: _tab, onTab: go, onAssistant: () => openVoice(context)),
      ),
    );
  }
}

/// Switch the bottom tab from anywhere (e.g. a home shortcut).
void goToTab(BuildContext context, ShellTab t, {MoneyPart? money}) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  HomeShellState.current?.go(t, money: money);
}

/// The assistant, listening.
void openVoice(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ChatHome(listen: true)));
}

/// The assistant, ready to type.
void openAssistant(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ChatHome()));
}

/// Something typed on another page: the assistant answers it.
void openChatWith(BuildContext context, String text) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ChatHome(firstMessage: text)));
}

/// A page opened from a shortcut (আমি, সব তথ্য…), with a way back above its title.
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

class _Nav extends StatelessWidget {
  const _Nav({required this.current, required this.onTab, required this.onAssistant});
  final ShellTab current;
  final void Function(ShellTab) onTab;
  final VoidCallback onAssistant;

  @override
  Widget build(BuildContext context) {
    Widget item(ShellTab t, IconData icon, IconData active, String label) {
      final on = t == current;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onTab(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(on ? active : icon, size: 24, color: on ? C.green : C.muted),
                const SizedBox(height: 2),
                Text(label, style: body(11.5, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? C.green : C.muted, height: 1.2)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(children: [
            item(ShellTab.home, Icons.home_outlined, Icons.home_rounded, 'হোম'),
            item(ShellTab.diary, Icons.event_note_outlined, Icons.event_note_rounded, 'দিনলিপি'),
            Expanded(
              child: Tooltip(
                message: 'সহকারী',
                child: Semantics(
                  button: true,
                  label: 'সহকারী',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onAssistant,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: C.green,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 1),
                      Text('সহকারী', style: body(11.5, weight: FontWeight.w600, color: C.green, height: 1.2)),
                    ]),
                  ),
                ),
              ),
            ),
            item(ShellTab.money, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'হিসাব'),
            item(ShellTab.store, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'সংরক্ষণ'),
          ]),
        ),
      ),
    );
  }
}
