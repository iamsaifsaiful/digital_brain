import 'package:flutter/material.dart';

import '../state/brain.dart';
import '../ui/theme.dart';
import 'assistant_bar.dart';
import 'chat_home.dart';
import 'diary_screen.dart';
import 'home_page.dart';
import 'ledger_screen.dart';
import 'store_screen.dart';
import '../logic/lang.dart';

/// হোম · দিনলিপি · হিসাব · সংরক্ষণ — an organiser, with the assistant's
/// box and mic at the bottom of every page.
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
    // The recogniser starts in the background, so the first mic tap listens at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BrainScope.read(context).services.voice.warmUp();
    });
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
        body: Column(children: [
          Expanded(
            child: IndexedStack(
              index: _tab.index,
              children: [
                const HomePage(),
                const SafeArea(bottom: false, child: DiaryScreen()),
                SafeArea(bottom: false, child: MoneyScreen(key: _money)),
                const SafeArea(bottom: false, child: StoreScreen()),
              ],
            ),
          ),
          // One box for every page: find, save or ask; the mic beside it.
          // (Easy mode has its own big buttons.) In the body, so it rides above the keyboard.
          if (!BrainScope.of(context).easyMode || _tab != ShellTab.home) AssistantBar(questions: _tab == ShellTab.home),
        ]),
        bottomNavigationBar: _Nav(current: _tab, onTab: go),
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
                  tooltip: tr('ফিরে যান'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.chevron_left_rounded, size: 30, color: C.ink),
                ),
              ),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}

class _Nav extends StatelessWidget {
  const _Nav({required this.current, required this.onTab});
  final ShellTab current;
  final void Function(ShellTab) onTab;

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
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 30,
                decoration: BoxDecoration(color: on ? C.greenTint : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                child: Icon(on ? active : icon, size: 23, color: on ? C.greenDark : C.muted),
              ),
              const SizedBox(height: 3),
              Text(label, style: body(12, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? C.greenDark : C.muted, height: 1.2)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line2))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            item(ShellTab.home, Icons.home_outlined, Icons.home_rounded, tr('হোম')),
            item(ShellTab.diary, Icons.event_note_outlined, Icons.event_note_rounded, tr('দিনলিপি')),
            item(ShellTab.money, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, tr('হিসাব')),
            item(ShellTab.store, Icons.inventory_2_outlined, Icons.inventory_2_rounded, tr('সংরক্ষণ')),
          ]),
        ),
      ),
    );
  }
}
