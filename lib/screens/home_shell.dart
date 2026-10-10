import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'home_screen.dart';
import 'ledger_screen.dart';
import 'library_screen.dart';
import 'more_screen.dart';
import 'voice_screen.dart';

/// আজ · হিসাব · (বলুন) · তথ্য · আমি — what a busy person checks most is
/// first, and speaking is always one tap in the middle.
enum ShellTab { home, money, library, me }

/// Lets a page switch the bottom tab (e.g. the home tiles).
class ShellTabs extends InheritedWidget {
  const ShellTabs({super.key, required this.go, required super.child});
  final void Function(ShellTab) go;

  static void goTo(BuildContext context, ShellTab t) => context.getInheritedWidgetOfExactType<ShellTabs>()?.go(t);

  @override
  bool updateShouldNotify(ShellTabs oldWidget) => false;
}

void openVoice(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoiceScreen(), fullscreenDialog: true));

/// Something typed on a screen: the chat opens with it already answered.
void openChatWith(BuildContext context, String text) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceScreen(firstMessage: text), fullscreenDialog: true));

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  ShellTab _tab = ShellTab.home;

  void _go(ShellTab t) => setState(() => _tab = t);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == ShellTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(ShellTab.home);
      },
      child: ShellTabs(
        go: _go,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab.index,
              children: const [HomeScreen(), MoneyScreen(), LibraryScreen(), MoreScreen()],
            ),
          ),
          bottomNavigationBar: _BottomNav(current: _tab, onTab: _go, onMic: () => openVoice(context)),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTab, required this.onMic});
  final ShellTab current;
  final void Function(ShellTab) onTab;
  final VoidCallback onMic;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? active : icon, size: 24, color: on ? C.green : C.muted),
                  const SizedBox(height: 2),
                  Text(label, style: body(12, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? C.green : C.muted, height: 1.2)),
                ],
              ),
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
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              item(ShellTab.home, Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'আজ'),
              item(ShellTab.money, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'হিসাব'),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'বলুন',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onMic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: C.green,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              item(ShellTab.library, Icons.folder_open_outlined, Icons.folder_rounded, 'তথ্য'),
              item(ShellTab.me, Icons.person_outline_rounded, Icons.person_rounded, 'আমি'),
            ],
          ),
        ),
      ),
    );
  }
}
