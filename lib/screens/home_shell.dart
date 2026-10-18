import 'package:flutter/material.dart';

import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show SwipeSwitch;
import 'assistant_bar.dart';
import 'chat_home.dart';
import 'diary_screen.dart';
import 'home_page.dart';
import 'ledger_screen.dart';
import 'store_screen.dart';
import 'more_screen.dart' show MoreScreen;
import '../logic/lang.dart';

/// হোম · দিনলিপি · হিসাব · সংরক্ষণ · আরও — an organiser, with the
/// assistant's box and mic at the bottom of every page. আরও holds the
/// settings, requests, Pro and feedback.
enum ShellTab { home, diary, money, store, more }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  /// The open shell, so a page can switch tabs ([goToTab]).
  static HomeShellState? current;

  ShellTab _tab = ShellTab.home;
  ShellTab get tabNow => _tab;
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
    _pages.dispose();
    super.dispose();
  }

  /// The tabs side by side: a swipe drags the page along with the finger.
  final _pages = PageController();

  /// [slide]: moved there with the pages sliding (a swipe that went past an
  /// inner tab's end); a tap on the bottom bar jumps.
  void go(ShellTab t, {MoneyPart? money, bool slide = false}) {
    setState(() => _tab = t);
    if (_pages.hasClients && (_pages.page?.round() ?? -1) != t.index) {
      if (slide) {
        _pages.animateToPage(t.index, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
      } else {
        _pages.jumpToPage(t.index);
      }
    }
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
            // Swiping across the page moves to the next (or previous) tab.
            // A page with tabs of its own takes the swipe first and hands it
            // on here at its last tab ([SwipeSwitch] without gestures).
            child: SwipeSwitch(
              key: const Key('shell-swipe'),
              gestures: false,
              onStep: (step) {
                final i = _tab.index + step;
                if (i < 0 || i >= ShellTab.values.length) return false;
                go(ShellTab.values[i], slide: true);
                return true;
              },
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  if (_tab.index != i) setState(() => _tab = ShellTab.values[i]);
                },
                children: [
                  const _Kept(HomePage()),
                  const _Kept(SafeArea(bottom: false, child: DiaryScreen())),
                  _Kept(SafeArea(bottom: false, child: MoneyScreen(key: _money))),
                  const _Kept(SafeArea(bottom: false, child: StoreScreen())),
                  const _Kept(SafeArea(bottom: false, child: MoreScreen())),
                ],
              ),
            ),
          ),
          // One box for every page: find, save or ask; the mic beside it.
          // (Easy mode has its own big buttons.) In the body, so it rides above the keyboard.
          if ((!BrainScope.of(context).easyMode || _tab != ShellTab.home) && _tab != ShellTab.more) AssistantBar(questions: _tab == ShellTab.home),
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

/// The assistant with the list of earlier conversations open.
void openPastChats(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ChatHome(showPast: true)));
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
    final unread = BrainScope.of(context).feedbackUnread > 0;
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
                child: Badge(
                  isLabelVisible: t == ShellTab.more && unread,
                  smallSize: 9,
                  child: Icon(on ? active : icon, size: 23, color: on ? C.greenDark : C.muted),
                ),
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
            item(ShellTab.more, Icons.menu_rounded, Icons.menu_open_rounded, tr('আরও')),
          ]),
        ),
      ),
    );
  }
}

/// A tab page kept alive while another is shown (its scroll place and state stay).
class _Kept extends StatefulWidget {
  const _Kept(this.child);
  final Widget child;

  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
