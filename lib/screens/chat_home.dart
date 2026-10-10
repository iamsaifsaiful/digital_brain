import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../state/chat.dart';
import '../state/chat_archive.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import 'calls_screen.dart';
import 'confirm_screen.dart';
import 'help_screen.dart';
import 'home_screen.dart';
import 'home_shell.dart';
import 'ledger_form_screen.dart';
import 'ledger_screen.dart';
import 'library_screen.dart';
import 'money_screens.dart';
import 'more_screen.dart';
import 'new_item_screen.dart';
import 'notes_screen.dart';
import 'person_screen.dart';
import 'plan_screens.dart';
import 'vault_item_screen.dart';
import 'vault_screen.dart';

/// The home: one conversation, like Claude or ChatGPT. Type or speak at
/// the bottom; everything else is in the menu on the left.
class ChatHome extends StatefulWidget {
  const ChatHome({super.key});

  @override
  State<ChatHome> createState() => ChatHomeState();
}

class ChatHomeState extends State<ChatHome> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The open home, so other pages can start talking ([openVoice]).
  static ChatHomeState? current;

  final _scaffold = GlobalKey<ScaffoldState>();
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final Brain _brain = BrainScope.read(context);
  late final ChatArchive _archive = ChatArchive(_brain.services.lock.keys);
  late ChatController _chat = _make();
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  List<SavedChat> _past = const [];

  /// Questions asked often, as one-tap chips above the text box; the user
  /// can add their own and remove any (kept in `quick_questions`).
  List<String> _questions = defaultQuestions;
  static const defaultQuestions = [
    'আজকের কাজের লিস্ট দাও',
    'আমার মোট পাওনা কত?',
    'আমি কাকে কত দেব?',
    'এই মাসে কত খরচ হলো?',
    'আজ আমার কী কী আছে?',
  ];
  String _chatId = '';
  int _savedCount = 0;
  Future<void> _saving = Future.value();

  String _live = '';
  String? _error;
  bool _voice = false;
  bool _listening = false;
  bool _speaking = false;
  bool _busy = false;

  /// Away on another screen: do not listen meanwhile.
  bool _away = false;
  int _gen = 0;
  int _silences = 0;

  static const _suggestions = [
    ('টাকা দিলাম', 'রবিনকে ৫০০০ টাকা ধার দিলাম'),
    ('মনে করাও', 'কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও'),
    ('কাজের তালিকা', 'আজকের কাজের তালিকা'),
    ('জিজ্ঞেস করুন', 'এই মাসে কত খরচ হলো?'),
  ];

  @override
  void initState() {
    super.initState();
    current = this;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPast());
  }

  @override
  void dispose() {
    if (current == this) current = null;
    WidgetsBinding.instance.removeObserver(this);
    _gen++;
    _chat
      ..removeListener(_changed)
      ..dispose();
    _wave.dispose();
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatController _make([List<ChatMessage> restored = const []]) => ChatController(_brain, restored: restored)..addListener(_changed);

  Future<void> _loadPast() async {
    final p = await _archive.load();
    List<String>? q;
    try {
      final raw = await _brain.services.lock.keys.read('quick_questions');
      if (raw != null) q = [for (final x in jsonDecode(raw) as List) '$x'];
    } catch (_) {}
    if (mounted) {
      setState(() {
        _past = p;
        if (q != null) _questions = q;
      });
    }
  }

  Future<void> _saveQuestions(List<String> q) async {
    setState(() => _questions = q);
    await _brain.services.lock.keys.write('quick_questions', jsonEncode(q));
  }

  Future<void> _addQuestion() async {
    final c = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('নতুন প্রশ্ন', style: body(18, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('যে প্রশ্ন প্রায়ই করেন, লিখে রাখুন — এক চাপে জিজ্ঞেস করা যাবে।', style: body(14, color: C.muted, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            style: body(16),
            decoration: const InputDecoration(hintText: 'যেমন: রহিমের কাছে কত পাব?'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাদ দিন')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('রাখুন', style: body(15, weight: FontWeight.w600, color: C.green))),
        ],
      ),
    );
    c.dispose();
    final t = q?.trim() ?? '';
    if (t.isEmpty || _questions.contains(t) || !mounted) return;
    await _saveQuestions([..._questions, t]);
  }

  Future<void> _removeQuestion(String q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('প্রশ্নটা সরাবেন?', style: body(18, weight: FontWeight.w600)),
        content: Text('“$q”', style: body(15, color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('সরান', style: body(15, weight: FontWeight.w600, color: C.red))),
        ],
      ),
    );
    if (ok == true && mounted) await _saveQuestions([..._questions.where((x) => x != q)]);
  }

  /// One-tap questions just above the text box.
  Widget _questionRow() => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          children: [
            for (final q in _questions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: C.ground,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _busy ? null : () => _send(q),
                    onLongPress: () => _removeQuestion(q),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Center(child: Text(q, style: body(14, color: C.muted2))),
                    ),
                  ),
                ),
              ),
            Material(
              color: C.surface,
              shape: const StadiumBorder(side: BorderSide(color: C.inputBorder)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _addQuestion,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, size: 18, color: C.green),
                    const SizedBox(width: 4),
                    Text('প্রশ্ন যোগ', style: body(14, weight: FontWeight.w600, color: C.green)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      );

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _toBottom();
    _persist();
  }

  /// Keeps this conversation in "আগের কথা" (on this phone only).
  void _persist() {
    if (!_chat.started || _chat.messages.length == _savedCount) return;
    _savedCount = _chat.messages.length;
    if (_chatId.isEmpty) _chatId = '${_brain.services.now().millisecondsSinceEpoch}';
    final c = SavedChat(id: _chatId, title: chatTitle(_chat.messages), at: _brain.services.now(), messages: keepable(_chat.messages));
    _saving = _saving.then((_) async {
      final all = await _archive.save(c);
      if (mounted) setState(() => _past = all);
    }).catchError((Object _) {});
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ── Conversations ──

  void _replaceChat(ChatController next, {String id = ''}) {
    _closeVoice();
    _chat
      ..removeListener(_changed)
      ..dispose();
    setState(() {
      _chat = next;
      _chatId = id;
      _savedCount = next.messages.length;
      _error = null;
      _text.clear();
    });
  }

  /// "নতুন কথা": a clean page.
  void newChat() {
    if (!_chat.started) return;
    _replaceChat(_make());
  }

  void _openPast(SavedChat c) {
    _replaceChat(_make(c.messages), id: c.id);
    _toBottom();
  }

  Future<void> _deletePast(SavedChat c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('এই কথাটা মুছবেন?', style: body(18, weight: FontWeight.w600)),
        content: Text('“${c.title}”', style: body(15, color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('মুছুন', style: body(15, weight: FontWeight.w600, color: C.red))),
        ],
      ),
    );
    if (ok != true) return;
    final all = await _archive.remove(c.id);
    if (!mounted) return;
    setState(() => _past = all);
    if (c.id == _chatId) _replaceChat(_make());
  }

  // ── Voice ──

  /// The big mic: listen, answer aloud, listen again — until ✕ or "থামো".
  Future<void> startVoice() async {
    if (!mounted) return;
    _focus.unfocus();
    final voice = _brain.services.voice;
    setState(() {
      _voice = true;
      _error = null;
    });
    _chat.ended = false;
    _silences = 0;
    if (!_chat.started && _chat.wait == ChatWait.none) {
      setState(() => _speaking = !voice.muted);
      try {
        await voice.speakAndWait('জি, বলুন।');
      } finally {
        if (mounted) setState(() => _speaking = false);
      }
    }
    if (mounted && _voice && !_listening && !_busy) unawaited(_listen());
  }

  void _closeVoice() {
    if (!_voice && !_listening) return;
    _stopListening();
    unawaited(_brain.services.voice.stopSpeaking());
    if (mounted) setState(() => _voice = false);
  }

  void _typeInstead() {
    _closeVoice();
    _focus.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_voice) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_listening) _stopListening();
    } else if (state == AppLifecycleState.resumed) {
      if (!_away && !_chat.ended && !_busy && !_listening && !_speaking && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _silences = 0;
        _listen();
      }
    }
  }

  Future<void> _listen() async {
    if (!mounted || _away || _busy || !_voice) return;
    final voice = _brain.services.voice;
    final gen = ++_gen;
    setState(() {
      _live = '';
      _error = null;
      _listening = true;
    });
    unawaited(_wave.repeat());
    await voice.listen(
      short: _chat.expectsShortAnswer,
      onWords: (w) {
        if (mounted && gen == _gen) setState(() => _live = w);
      },
      onDone: (w) {
        if (!mounted || gen != _gen) return;
        _wave.stop();
        setState(() {
          _listening = false;
          _live = '';
        });
        if (w.trim().isEmpty && _chat.hasPending) {
          // Went quiet after a list or a half sentence: now answer it.
          _silences = 0;
          unawaited(_flush());
        } else if (w.trim().isEmpty) {
          // Quiet for a while: keep listening a few rounds, then rest.
          _silences++;
          if (_silences < 4) {
            Future<void>.delayed(const Duration(milliseconds: 250), () {
              if (mounted && gen == _gen) _listen();
            });
          } else {
            setState(() => _error = 'অনেকক্ষণ কিছু শুনিনি, তাই মাইক বন্ধ রাখলাম। বলতে চাইলে “বলুন” চাপুন।');
          }
        } else {
          _silences = 0;
          _send(w);
        }
      },
      onError: (m) {
        if (!mounted || gen != _gen) return;
        _wave.stop();
        setState(() => _listening = false);
        _silences++;
        if (_silences < 3 && !m.contains('অনুমতি') && !m.contains('চালু')) {
          Future<void>.delayed(const Duration(milliseconds: 900), () {
            if (mounted && gen == _gen) _listen();
          });
        } else {
          setState(() => _error = '$m “বলুন” চাপলে আবার শুনব।');
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _gen++;
    _wave.stop();
    final was = _listening;
    if (mounted) setState(() => _listening = false);
    if (was) await _brain.services.voice.cancel();
  }

  /// "শেষ" / "বলুন" in the voice view.
  void _voiceMain() {
    if (_busy) return;
    if (_listening) {
      // Finish what was heard so far.
      _brain.services.voice.stop();
    } else if (_chat.hasPending) {
      _flush();
    } else {
      _brain.services.voice.stopSpeaking();
      _silences = 0;
      _chat.ended = false;
      _listen();
    }
  }

  /// Typed or spoken: answered, and spoken aloud only in the voice view.
  Future<void> send(String said) => _send(said);

  Future<void> _send(String said) async {
    if (said.trim().isEmpty || _busy) return;
    await _stopListening();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var say = '';
    try {
      say = await _chat.hear(said);
    } catch (e) {
      debugPrint('chat failed: $e');
      say = 'দুঃখিত, একটু সমস্যা হলো। আরেকবার বলবেন?';
      _chat.addInfo(say);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _after(say);
  }

  Future<void> _flush() async {
    if (_busy) return;
    setState(() => _busy = true);
    var say = '';
    try {
      say = await _chat.flush();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _after(say);
  }

  Future<void> _after(String say) async {
    final voice = _brain.services.voice;
    if (_voice && say.isNotEmpty) {
      setState(() => _speaking = !voice.muted);
      try {
        await voice.speakAndWait(say);
      } finally {
        if (mounted) setState(() => _speaking = false);
      }
    }
    if (!mounted) return;
    if (_chat.pendingLaunch != null) await _chat.launchPending();
    if (!mounted) return;
    _silences = 0;
    if (_voice && _chat.ended) setState(() => _voice = false);
    if (_voice && !_listening && !_away) unawaited(_listen());
  }

  void _submitTyped() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    _send(t);
  }

  // ── Other pages ──

  /// Opens another page; listening pauses and starts again on return.
  Future<Object?> _open(Widget screen) async {
    _away = true;
    await _stopListening();
    if (!mounted) return null;
    unawaited(_brain.services.voice.stopSpeaking());
    final r = await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => screen));
    _away = false;
    if (mounted && _voice && !_chat.ended) unawaited(_listen());
    return r;
  }

  void _menuOpen(Widget screen) {
    Navigator.of(context).pop(); // the drawer
    _open(screen);
  }

  Future<void> _openVault(VaultItem v) async {
    _away = true;
    await _stopListening();
    if (!mounted) return;
    final ok = await verifyUser(context, reason: '${v.name} — তথ্য দেখতে যাচাই করুন');
    _away = false;
    if (ok && mounted) await _open(VaultItemScreen(id: v.id));
  }

  void _link(ChatLink l) {
    switch (l.kind) {
      case LinkKind.person:
        _open(PersonScreen(person: l.person!));
      case LinkKind.notes:
        _open(const NotesScreen());
      case LinkKind.reminders:
      case LinkKind.tasks:
        _open(const AllTasksScreen());
      case LinkKind.contacts:
        _open(const CallsScreen());
      case LinkKind.cash:
        _open(const CashPage());
      case LinkKind.editEntry:
        _chat.dropPending();
        _open(ConfirmScreen(command: l.entry!)).then((r) {
          if (r is String) _chat.addInfo(r);
        });
    }
  }

  Future<void> _quickAdd() async {
    _closeVoice();
    _focus.unfocus();
    final pick = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: C.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _QuickAddSheet(),
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case 0:
        await showAddSheet(context);
      case 1:
        await _open(const LedgerFormScreen());
      case 2:
        await _open(const CashFormScreen());
      case 3:
        await _open(const NewItemScreen(category: ItemCategory.note));
      case 4:
        await _open(const NewItemScreen(category: ItemCategory.password));
      case 5:
        await _open(const NewItemScreen(category: ItemCategory.contact));
      case 6:
        await importFromPhone(context);
    }
  }

  // ── Building ──

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return PopScope(
      canPop: !_voice,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeVoice();
      },
      child: Scaffold(
        key: _scaffold,
        backgroundColor: C.surface,
        drawer: _Menu(
          brain: brain,
          past: _past,
          currentId: _chatId,
          onNew: () {
            Navigator.of(context).pop();
            newChat();
          },
          onOpen: (w) => _menuOpen(w),
          onPast: (c) {
            Navigator.of(context).pop();
            _openPast(c);
          },
          onDeletePast: _deletePast,
        ),
        body: SafeArea(
          child: _voice
              ? _voiceView()
              : Column(children: [
                  _topBar(),
                  Expanded(child: _chat.started ? _conversation() : _welcome(brain)),
                  if (_chat.choices.isNotEmpty) _choiceRow() else _questionRow(),
                  _composer(),
                ]),
        ),
      ),
    );
  }

  Widget _topBar() {
    final title = _chat.started ? chatTitle(_chat.messages) : 'My Assistant';
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _chat.started ? C.line2 : Colors.transparent))),
      child: Row(children: [
        IconButton(
          tooltip: 'মেনু',
          onPressed: () {
            _focus.unfocus();
            _scaffold.currentState?.openDrawer();
          },
          icon: const Icon(Icons.notes_rounded, size: 26, color: C.ink),
        ),
        Expanded(
          child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600)),
        ),
        IconButton(
          tooltip: 'নতুন কথা',
          onPressed: _chat.started ? newChat : null,
          icon: Icon(Icons.edit_square, size: 22, color: _chat.started ? C.ink : C.inputBorder),
        ),
      ]),
    );
  }

  String _hello(DateTime now) {
    final h = now.hour;
    if (h >= 4 && h < 11) return 'সুপ্রভাত';
    if (h >= 11 && h < 15) return 'শুভ দুপুর';
    if (h >= 15 && h < 18) return 'শুভ বিকেল';
    if (h >= 18 && h < 22) return 'শুভ সন্ধ্যা';
    return 'শুভ রাত';
  }

  Widget _welcome(Brain brain) {
    final d = brain.data;
    final now = brain.services.now();
    final plan = planOf(d, now);
    final t = totals(d.ledger);
    final month = monthSums(d.cash, now);
    final owing = balances(d.ledger).where((p) => p.balance > 0).length;
    final next = plan.today.where((i) => i.task == null || !i.task!.done).firstOrNull;
    final left = plan.today.where((i) => i.task == null || !i.task!.done).length;

    Widget glance(String label, String value, String sub, {Color? color, Color? subColor, double flex = 1, required VoidCallback onTap}) =>
        Expanded(
          flex: (flex * 100).round(),
          child: Material(
            color: C.ground,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: body(12, color: C.muted, height: 1.3)),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, color: color ?? C.ink, height: 1.35)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: subColor ?? C.muted, height: 1.3)),
                ]),
              ),
            ),
          ),
        );

    Widget suggestion((String, String) s) => Expanded(
          child: Material(
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _send(s.$2),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$1, style: body(14, weight: FontWeight.w600, height: 1.35)),
                  Text('“${s.$2}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted, height: 1.35)),
                ]),
              ),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerLeft, child: _Mark(size: 44)),
        const SizedBox(height: 14),
        Text(_hello(now), style: display(28, weight: 700, height: 1.2)),
        Text('আজ কী করে দেব?', style: body(18, color: C.muted, height: 1.4)),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          glance('আজ', left == 0 ? 'কিছু বাকি নেই' : '${bnDigits(left)}টা কাজ বাকি',
              next == null ? 'সব দেখুন' : 'পরেরটা ${bnTime(next.sort.hour, next.sort.minute)}',
              subColor: C.green, flex: 1.25, onTap: () => _open(const AllTasksScreen())),
          const SizedBox(width: 8),
          glance('পাওনা', taka(t.receivable), owing == 0 ? 'কারো কাছে নেই' : '${bnDigits(owing)} জনের কাছে',
              color: C.green, onTap: () => _open(const MenuPage(child: MoneyScreen(initial: MoneyPart.loans)))),
          const SizedBox(width: 8),
          glance('এ মাসে খরচ', taka(month.expense), 'ব্যালেন্স ${month.balance < 0 ? '-' : ''}${taka(month.balance)}',
              onTap: () => _open(const MenuPage(child: MoneyScreen()))),
        ]),
        const StartTips(),
        if (d.reminders.isNotEmpty) const AlarmBanner(),
        const TodaySections(),
        const SizedBox(height: 8),
        Text('এভাবে বলতে বা লিখতে পারেন', style: body(13, weight: FontWeight.w600, color: C.muted)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          suggestion(_suggestions[0]),
          const SizedBox(width: 8),
          suggestion(_suggestions[1]),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          suggestion(_suggestions[2]),
          const SizedBox(width: 8),
          suggestion(_suggestions[3]),
        ]),
      ],
    );
  }

  Widget _conversation() => ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          for (final m in _chat.messages) _message(m),
          if (_chat.thinking || _busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const _Mark(size: 28),
                const SizedBox(width: 10),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.green)),
                const SizedBox(width: 8),
                Text('ভাবছি…', style: body(14, color: C.muted)),
              ]),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, textAlign: TextAlign.center, style: body(13, color: C.orangeDark, height: 1.4)),
            ),
        ],
      );

  Widget _message(ChatMessage m) {
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8, left: 56),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(m.text, style: body(16, height: 1.45)),
        ),
      );
    }
    if (m.info) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(38, 2, 8, 6),
        child: Text(m.text, style: body(13, color: C.muted, height: 1.4)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Mark(size: 28),
        const SizedBox(width: 10),
        Expanded(child: _reply(m)),
      ]),
    );
  }

  /// An answer: plain text, then the things found (as a card), logins to
  /// open and links.
  Widget _reply(ChatMessage m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(m.text, style: body(16, height: 1.5)),
          ),
          if (m.facts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                for (final (i, f) in m.facts.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: C.line2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(8)),
                        child: Text(bnDigits(i + 1), style: body(12, weight: FontWeight.w700, color: C.green, height: 1)),
                      ),
                      Expanded(child: Text(f, style: body(15, weight: FontWeight.w500, height: 1.4))),
                    ]),
                  ),
                ],
              ]),
            ),
          ],
          if (m.vault.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                for (final v in m.vault.take(8))
                  InkWell(
                    onTap: () => _openVault(v),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(children: [
                        const Icon(Icons.lock_outline_rounded, color: C.blue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(v.name, style: body(15, weight: FontWeight.w600))),
                        Text('খুলুন', style: body(14, color: C.green, weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
          if (m.links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in m.links)
                  Material(
                    color: C.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _link(l),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text('${l.label} →', style: body(13, weight: FontWeight.w500)),
                      ),
                    ),
                  ),
              ]),
            ),
        ],
      );

  Widget _chip(ChatChoice c) {
    final yes = c.answer == 'হ্যাঁ';
    return ActionChip(
      label: Text(c.label, style: body(15, weight: FontWeight.w600, color: yes ? Colors.white : C.ink)),
      backgroundColor: yes ? C.ink : C.surface,
      side: yes ? BorderSide.none : const BorderSide(color: C.inputBorder),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onPressed: _busy ? null : () => _send(c.answer),
    );
  }

  /// "হ্যাঁ" first, as in the design; other lists keep their order.
  List<ChatChoice> _ordered(List<ChatChoice> cs) => [...cs.where((c) => c.answer == 'হ্যাঁ'), ...cs.where((c) => c.answer != 'হ্যাঁ')];

  Widget _choiceRow() => Padding(
        padding: const EdgeInsets.fromLTRB(54, 0, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, runSpacing: 8, children: [for (final c in _ordered(_chat.choices)) _chip(c)]),
        ),
      );

  Widget _composer() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.inputBorder),
              boxShadow: const [BoxShadow(color: Color(0x0F111827), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _Round(icon: Icons.add_rounded, tooltip: 'দ্রুত যোগ', bg: const Color(0xFFF3F4F6), fg: C.ink, size: 40, onTap: _quickAdd),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitTyped(),
                  style: body(16),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'লিখুন বা কথা বলুন…',
                    hintStyle: body(16, color: const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, v, _) => v.text.trim().isEmpty
                    ? _Round(icon: Icons.mic_none_rounded, tooltip: 'কথা বলুন', bg: C.green, fg: Colors.white, size: 44, onTap: startVoice)
                    : _Round(icon: Icons.arrow_upward_rounded, tooltip: 'পাঠান', bg: C.ink, fg: Colors.white, size: 44, onTap: _busy ? null : _submitTyped),
              ),
            ]),
          ),
          if (!_chat.started)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('হিসাব আর পাসওয়ার্ড শুধু আপনার ফোনেই থাকে', style: body(12, color: C.muted)),
            ),
        ]),
      );

  /// Talking: a big breathing circle, what is being heard, and the last
  /// answer with its buttons.
  Widget _voiceView() {
    final msgs = _chat.messages;
    final lastUser = msgs.lastIndexWhere((m) => m.fromUser);
    final replies = [for (final m in msgs.skip(lastUser + 1)) if (!m.fromUser) m];
    final status = _listening
        ? 'শুনছি…'
        : (_busy || _chat.thinking)
            ? 'ভাবছি…'
            : _speaking
                ? 'বলছি…'
                : 'মাইক বন্ধ';
    final hint = _chat.collecting ? 'বলে যান — তালিকা শেষ হলে “শেষ” বলুন।' : 'বলে যান — থামলে আমি বুঝে নেব।';
    return Column(children: [
      const SizedBox(height: 14),
      Text(status, style: body(14, color: C.muted)),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          children: [
            Center(child: _Orb(animation: _wave, active: _listening || _speaking)),
            const SizedBox(height: 28),
            if (_listening && _live.isNotEmpty)
              Text(_live, textAlign: TextAlign.center, style: body(20, weight: FontWeight.w500, height: 1.5))
            else if (lastUser >= 0 && !_listening && replies.isEmpty)
              Text(msgs[lastUser].text, textAlign: TextAlign.center, style: body(18, color: C.muted, height: 1.5)),
            if (!_listening || _live.isEmpty)
              for (final m in replies) ...[
                if (m.info)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(m.text, textAlign: TextAlign.center, style: body(13, color: C.muted, height: 1.4)),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Text(m.text, textAlign: TextAlign.center, style: body(18, weight: FontWeight.w500, height: 1.5)),
                  if (m.facts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text([for (final (i, f) in m.facts.indexed) '${bnDigits(i + 1)}. $f'].join('\n'),
                          textAlign: TextAlign.center, style: body(15, color: C.muted2, height: 1.6)),
                    ),
                  for (final v in m.vault.take(4))
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _openVault(v),
                        icon: const Icon(Icons.lock_outline_rounded, size: 18, color: C.blue),
                        label: Text(v.name, style: body(15, weight: FontWeight.w600)),
                      ),
                    ),
                  if (m.links.isNotEmpty)
                    Wrap(alignment: WrapAlignment.center, children: [
                      for (final l in m.links)
                        TextButton(onPressed: () => _link(l), child: Text('${l.label} →', style: body(14, weight: FontWeight.w600, color: C.green))),
                    ]),
                ],
              ],
            const SizedBox(height: 14),
            if (_listening) Text(hint, textAlign: TextAlign.center, style: body(14, color: C.muted, height: 1.5)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, textAlign: TextAlign.center, style: body(14, color: C.orangeDark, height: 1.5)),
              ),
            if (_chat.choices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [for (final c in _ordered(_chat.choices)) _chip(c)]),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Round(icon: Icons.keyboard_alt_outlined, tooltip: 'লিখে বলুন', bg: const Color(0xFFF3F4F6), fg: C.ink, size: 56, onTap: _typeInstead),
          const SizedBox(width: 24),
          Semantics(
            button: true,
            label: _listening ? 'শেষ' : 'বলুন',
            excludeSemantics: true,
            child: Material(
              color: C.ink,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _busy ? null : _voiceMain,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Center(child: Text(_listening ? 'শেষ' : 'বলুন', style: body(17, weight: FontWeight.w600, color: Colors.white))),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          _Round(icon: Icons.close_rounded, tooltip: 'বন্ধ করুন', bg: const Color(0xFFF3F4F6), fg: C.ink, size: 56, onTap: _closeVoice),
        ]),
      ),
    ]);
  }
}

/// The app's mark: a green tile with a sparkle.
class _Mark extends StatelessWidget {
  const _Mark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size * 0.55),
      );
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.bg, required this.fg, required this.size, required this.onTap});
  final IconData icon;
  final String tooltip;
  final Color bg;
  final Color fg;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, color: fg, size: size * 0.5)),
          ),
        ),
      );
}

/// A green circle that breathes while listening or speaking.
class _Orb extends AnimatedWidget {
  const _Orb({required Animation<double> animation, required this.active}) : super(listenable: animation);
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final s = active ? 1 + 0.07 * sin(2 * pi * t) : 1.0;
    final ring = active ? t : 0.0;
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(alignment: Alignment.center, children: [
        if (active)
          Container(
            width: 170 * (1 + 0.45 * ring),
            height: 170 * (1 + 0.45 * ring),
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.green.withValues(alpha: 0.28 * (1 - ring))),
          ),
        Transform.scale(
          scale: s,
          child: Container(
            width: 170,
            height: 170,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFF34B48E), C.green, C.greenDark], stops: [0, 0.6, 1]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The left menu: new chat, every page, earlier chats, and "আমি".
class _Menu extends StatelessWidget {
  const _Menu({
    required this.brain,
    required this.past,
    required this.currentId,
    required this.onNew,
    required this.onOpen,
    required this.onPast,
    required this.onDeletePast,
  });

  final Brain brain;
  final List<SavedChat> past;
  final String currentId;
  final VoidCallback onNew;
  final void Function(Widget) onOpen;
  final void Function(SavedChat) onPast;
  final void Function(SavedChat) onDeletePast;

  @override
  Widget build(BuildContext context) {
    final d = brain.data;
    final now = brain.services.now();
    final plan = planOf(d, now);
    final left = plan.today.where((i) => i.task == null || !i.task!.done).length;
    final t = totals(d.ledger);

    Widget item(IconData icon, String label, Widget page, {String? note}) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpen(page),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(icon, size: 21, color: C.muted2),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: body(16))),
                if (note != null) Text(note, style: body(12, color: C.muted)),
              ]),
            ),
          ),
        );

    return Drawer(
      width: 304,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Material(
              color: C.ink,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onNew,
                child: SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      const Icon(Icons.edit_square, size: 18, color: Colors.white),
                      const SizedBox(width: 10),
                      Text('নতুন কথা', style: body(15, weight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onNew,
              child: SizedBox(
                height: 46,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Icon(Icons.home_outlined, size: 21, color: C.muted2),
                    const SizedBox(width: 14),
                    Expanded(child: Text('হোম', style: body(16))),
                    if (left > 0) Text('আজ ${bnDigits(left)} বাকি', style: body(12, color: C.muted)),
                  ]),
                ),
              ),
            ),
            item(Icons.notifications_none_rounded, 'কাজ ও রিমাইন্ডার', const AllTasksScreen()),
            item(Icons.account_balance_wallet_outlined, 'হিসাব', const MenuPage(child: MoneyScreen()),
                note: t.receivable == 0 ? null : 'পাওনা ${taka(t.receivable)}'),
            item(Icons.person_outline_rounded, 'যোগাযোগ', const CallsScreen()),
            item(Icons.sticky_note_2_outlined, 'নোট', const NotesScreen()),
            item(Icons.lock_outline_rounded, 'পাসওয়ার্ড', const VaultPage()),
            item(Icons.folder_open_outlined, 'সব তথ্য ও বিভাগ', const MenuPage(child: LibraryScreen())),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Text('আগের কথা', style: body(12, weight: FontWeight.w600, color: C.muted)),
            ),
            Expanded(
              child: past.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('এখনো কিছু নেই। আগের কথাগুলো শুধু এই ফোনে থাকে।', style: body(13, color: C.muted, height: 1.4)),
                    )
                  : ListView(padding: EdgeInsets.zero, children: [
                      for (final c in past)
                        Material(
                          color: c.id == currentId ? const Color(0xFFF3F4F6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onPast(c),
                            onLongPress: () => onDeletePast(c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, color: C.muted2)),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        child: Text('শুধু এই ফোনে থাকে · মুছতে চেপে ধরে রাখুন', style: body(12, color: const Color(0xFF9CA3AF))),
                      ),
                    ]),
            ),
            const Divider(height: 1, color: C.line2),
            InkWell(
              onTap: () => onOpen(const MenuPage(child: MoreScreen())),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: C.green, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('আমি', style: body(15, weight: FontWeight.w600)),
                      Text('প্ল্যান · ব্যাকআপ · সেটিংস', style: body(12, color: C.muted)),
                    ]),
                  ),
                  const Icon(Icons.settings_outlined, color: C.muted, size: 20),
                ]),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onOpen(const HelpScreen()),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18, color: C.green),
                label: Text('কী কী করা যায়', style: body(13, weight: FontWeight.w600, color: C.green)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "+": forms for those who would rather not speak or type a sentence.
class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    Widget tile(int i, IconData icon, String label, Color fg, Color bg) => Material(
          color: C.ground,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context, i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: fg, size: 21),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: body(13, height: 1.3)),
              ]),
            ),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ফর্মে যোগ করুন', style: body(16, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: tile(0, Icons.notifications_none_rounded, 'কাজ / রিমাইন্ডার', C.orange, C.orangeTint)),
            const SizedBox(width: 8),
            Expanded(child: tile(1, Icons.swap_horiz_rounded, 'ধার-দেনা', C.green, C.greenTint)),
            const SizedBox(width: 8),
            Expanded(child: tile(2, Icons.account_balance_wallet_outlined, 'খরচ / আয়', C.green, C.greenTint)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: tile(3, Icons.sticky_note_2_outlined, 'নোট', C.blue, C.blueTint)),
            const SizedBox(width: 8),
            Expanded(child: tile(4, Icons.lock_outline_rounded, 'পাসওয়ার্ড', C.ink, const Color(0xFFF3F4F6))),
            const SizedBox(width: 8),
            Expanded(child: tile(5, Icons.call_outlined, 'নম্বর রাখুন', C.ink, const Color(0xFFF3F4F6))),
          ]),
          const SizedBox(height: 12),
          Material(
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(context, 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.download_rounded, color: C.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ফোনবুক থেকে নম্বর আনুন', style: body(15, weight: FontWeight.w600)),
                      Text('এক চাপে সব, একই নম্বর দুবার আসবে না', style: body(12, color: C.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('টিপস: ফর্ম না খুলে সরাসরি লিখে বা বলেও দিতে পারেন — “বাজারে ৫০০ টাকা খরচ”।', style: body(13, color: C.muted, height: 1.5)),
        ]),
      ),
    );
  }
}
