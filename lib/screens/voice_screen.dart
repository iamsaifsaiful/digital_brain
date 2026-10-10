import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/brain.dart';
import '../state/chat.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import 'confirm_screen.dart';
import 'calls_screen.dart';
import 'money_screens.dart';
import 'notes_screen.dart';
import 'person_screen.dart';
import 'plan_screens.dart';
import 'vault_item_screen.dart';

/// A conversation by voice (or typing): the app answers, then listens
/// again, until the user closes it or says "থামো".
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key, this.startTyping = false, this.firstMessage});
  final bool startTyping;

  /// Typed on the আজ screen: answered straight away, no opening question.
  final String? firstMessage;

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final ChatController _chat = ChatController(BrainScope.read(context))..addListener(_changed);
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  String _live = '';
  String? _error;
  bool _listening = false;
  bool _speaking = false;
  bool _typing = false;
  bool _busy = false;

  /// Away on another screen: do not listen meanwhile.
  bool _away = false;
  int _gen = 0;
  int _silences = 0;

  static const _examples = [
    'আজ আমার কী কী আছে?',
    'কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও',
    'কাল ব্যাংকে যেতে হবে',
    'রহিমকে ফোন দাও',
    'করিম ৫০০ টাকার মাল বাকিতে নিল',
    'আমি কার কাছে কত টাকা পাব?',
    'মনে রাখো: গাড়ির কাগজ আলমারিতে',
    'তুমি কী কী পারো?',
  ];

  @override
  void initState() {
    super.initState();
    _typing = widget.startTyping;
    WidgetsBinding.instance.addObserver(this);
    final first = widget.firstMessage?.trim() ?? '';
    if (first.isNotEmpty) _typing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => first.isEmpty ? _begin() : _send(first));
  }

  /// "কী করতে চান — লেনদেন, রিমাইন্ডার…?", then listen.
  Future<void> _begin({bool again = false}) async {
    if (!mounted) return;
    final voice = BrainScope.read(context).services.voice;
    await _stopListening();
    final say = again ? _chat.chooseTopic() : _chat.greet();
    if (!mounted) return;
    setState(() => _speaking = !voice.muted);
    try {
      await voice.speakAndWait(say);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
    _silences = 0;
    if (mounted && !_typing && !_listening && !_away) unawaited(_listen());
  }

  /// Leaving the app (a call, the home button, screen off) stops the
  /// microphone; coming back picks the conversation up again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_listening) _stopListening();
    } else if (state == AppLifecycleState.resumed) {
      if (!_away && !_typing && !_chat.ended && !_busy && !_listening && !_speaking && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _silences = 0;
        _listen();
      }
    }
  }

  @override
  void dispose() {
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

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _listen() async {
    if (!mounted || _away || _busy) return;
    final voice = BrainScope.read(context).services.voice;
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
        if (mounted && gen == _gen) {
          setState(() => _live = w);
          _toBottom();
        }
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
          // Quiet for a while: keep listening a few rounds, then rest the
          // microphone until the user taps it.
          _silences++;
          if (_silences < 4) {
            Future<void>.delayed(const Duration(milliseconds: 250), () {
              if (mounted && gen == _gen) _listen();
            });
          } else {
            setState(() => _error = 'অনেকক্ষণ কিছু শুনিনি, তাই মাইক বন্ধ রাখলাম। বলতে চাইলে নিচের মাইক চাপুন।');
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
        // A passing hiccup: try again on its own a couple of times.
        _silences++;
        if (_silences < 3 && !m.contains('অনুমতি') && !m.contains('চালু')) {
          Future<void>.delayed(const Duration(milliseconds: 900), () {
            if (mounted && gen == _gen) _listen();
          });
        } else {
          setState(() => _error = '$m মাইক চাপলে আবার শুনব।');
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _gen++;
    _wave.stop();
    if (_listening) await BrainScope.read(context).services.voice.cancel();
    if (mounted) setState(() => _listening = false);
  }

  /// "বলা শেষ": finish what was heard so far.
  Future<void> _finishTurn() async {
    await BrainScope.read(context).services.voice.stop();
  }

  Future<void> _send(String said) async {
    if (said.trim().isEmpty || _busy) return;
    await _stopListening();
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
    if (!mounted) return;
    await _speakThenListen(say);
  }

  /// The list or half sentence the user left when they went quiet.
  Future<void> _flush() async {
    if (_busy) return;
    setState(() => _busy = true);
    var say = '';
    try {
      say = await _chat.flush();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _speakThenListen(say);
  }

  Future<void> _speakThenListen(String say) async {
    final voice = BrainScope.read(context).services.voice;
    setState(() => _speaking = say.isNotEmpty && !voice.muted);
    try {
      if (say.isNotEmpty) await voice.speakAndWait(say);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
    if (!mounted) return;
    if (_chat.pendingLaunch != null) await _chat.launchPending();
    if (!mounted) return;
    _silences = 0;
    if (!_typing && !_chat.ended && !_listening && !_away) unawaited(_listen());
  }

  void _toggleTyping() {
    _stopListening();
    setState(() {
      _typing = !_typing;
      _error = null;
    });
    if (_typing) {
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      _listen();
    }
  }

  void _submitTyped() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    _send(t);
  }

  void _micTap() {
    if (_listening) {
      _finishTurn();
    } else {
      BrainScope.read(context).services.voice.stopSpeaking();
      _silences = 0;
      _chat.ended = false;
      if (_typing) setState(() => _typing = false);
      _listen();
    }
  }

  /// Opens another screen; listening pauses and starts again on return.
  Future<Object?> _open(Widget screen) async {
    _away = true;
    await _stopListening();
    if (!mounted) return null;
    unawaited(BrainScope.read(context).services.voice.stopSpeaking());
    final r = await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => screen));
    _away = false;
    if (mounted && !_typing && !_chat.ended) unawaited(_listen());
    return r;
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
        _open(const AllTasksScreen());
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

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final msgs = _chat.messages;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _gen++;
          brain.services.voice.cancel();
          brain.services.voice.stopSpeaking();
        }
      },
      child: Scaffold(
        backgroundColor: C.ink,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'বন্ধ করুন',
                      child: Material(
                        color: C.dark2,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(width: 44, height: 44, child: Icon(Icons.close_rounded, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('কথা বলুন', style: display(20, color: Colors.white))),
                    if (_chat.topic != null)
                      Flexible(
                        child: Material(
                          color: C.dark2,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _busy ? null : () => _begin(again: true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Flexible(
                                  child: Text('বিষয়: ${_chat.topicLabel}',
                                      style: body(13, color: C.mint, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.swap_horiz_rounded, size: 16, color: C.mint),
                              ]),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3A4842)), borderRadius: BorderRadius.circular(999)),
                        child: Text(brain.aiOn ? 'AI চালু' : 'ভাষা: বাংলা', style: body(13, color: C.onDarkMuted)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  children: [
                    for (final m in msgs) _bubble(m),
                    if (!msgs.any((m) => m.fromUser)) _intro(),
                    if (_listening && _live.isNotEmpty) _userBubble(_live, live: true),
                    if (_chat.thinking) _status(const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.mint)), 'ভাবছি…'),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!, style: body(15, color: C.peach, weight: FontWeight.w600, height: 1.5)),
                      ),
                  ],
                ),
              ),
              if (_chat.choices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final c in _chat.choices)
                        ActionChip(
                          label: Text(c.label, style: body(16, weight: FontWeight.w600, color: C.ink)),
                          backgroundColor: c.answer == 'হ্যাঁ' ? C.mint : Colors.white,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          onPressed: _busy ? null : () => _send(c.answer),
                        ),
                    ],
                  ),
                ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('অনেক কথা একসাথে বললেও আমি আসল তথ্যগুলো আলাদা করে রাখব। থামাতে “থামো” বলুন।',
              style: body(14, color: const Color(0xFFA9B5AF))),
          const SizedBox(height: 18),
          Text('এভাবে বলতে পারেন', style: body(14, color: const Color(0xFFA9B5AF))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _examples)
                Material(
                  color: C.dark2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _send(e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('“$e”', style: body(14, color: const Color(0xFFE4EAE7))),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _status(Widget icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Row(children: [icon, const SizedBox(width: 10), Text(text, style: body(14, color: C.mint, weight: FontWeight.w600))]),
      );

  Widget _bubble(ChatMessage m) {
    if (m.fromUser) return _userBubble(m.text);
    if (m.info) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(m.text, textAlign: TextAlign.center, style: body(13, color: const Color(0xFFA9B5AF))),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 6, right: 36),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          color: C.dark2,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text, style: body(17, color: Colors.white, height: 1.45)),
            if (m.facts.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final (i, f) in m.facts.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      decoration: const BoxDecoration(color: Color(0xFF34443D), shape: BoxShape.circle),
                      child: Text('${i + 1}', style: body(12, color: C.mint, weight: FontWeight.w700)),
                    ),
                    Expanded(child: Text(f, style: body(15, color: const Color(0xFFE4EAE7)))),
                  ]),
                ),
            ],
            if (m.vault.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final v in m.vault.take(8))
                InkWell(
                  onTap: () => _openVault(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.lock_outline_rounded, color: C.mint, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(v.name, style: body(16, color: Colors.white, weight: FontWeight.w600))),
                      Text('খুলুন', style: body(14, color: C.mint, weight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ],
            if (m.links.isNotEmpty)
              Wrap(spacing: 4, children: [
                for (final l in m.links)
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 36)),
                    onPressed: () => _link(l),
                    child: Text('${l.label} →', style: body(14, color: C.mint, weight: FontWeight.w600)),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _userBubble(String text, {bool live = false}) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6, left: 48),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: live ? const Color(0xFF1F4A3E) : C.green,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(text, style: body(17, color: live ? C.onDarkMuted : Colors.white, height: 1.45)),
        ),
      );

  Widget _bottomBar() {
    if (_typing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        child: Row(
          children: [
            IconButton(
              tooltip: 'বলে বলুন',
              onPressed: _toggleTyping,
              icon: const Icon(Icons.mic_none_rounded, color: Colors.white),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitTyped(),
                style: body(17, color: Colors.white),
                cursorColor: C.mint,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: C.dark2,
                  hintText: 'লিখুন…',
                  hintStyle: body(16, color: const Color(0xFF8A9690)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: C.mint, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'পাঠান',
              style: IconButton.styleFrom(backgroundColor: C.green),
              onPressed: _busy ? null : _submitTyped,
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ],
        ),
      );
    }
    final label = _listening
        ? 'বলা শেষ'
        : _speaking
            ? 'থামিয়ে বলুন'
            : 'বলুন';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_listening) ...[
            _Wave(animation: _wave),
            const SizedBox(height: 4),
            Text(
                _chat.collecting
                    ? 'বলে যান… শেষ হলে বলুন “শেষ”'
                    : (_live.isEmpty ? 'শুনছি… বলা শেষ হলে একটু থামুন' : 'শুনছি… আরও বলতে পারেন'),
                style: body(13, color: const Color(0xFFA9B5AF))),
            const SizedBox(height: 8),
          ],
          if (!_listening && !_speaking && !_busy && !_chat.thinking) ...[
            Text('মাইক বন্ধ আছে — চাপলে আবার শুনব', style: body(13, color: C.mint, weight: FontWeight.w600)),
            const SizedBox(height: 8),
          ],
          // Always there: type instead of speaking — it is understood the same way.
          Material(
            color: C.dark2,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _toggleTyping,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.keyboard_alt_outlined, color: C.onDarkMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('এখানে লিখুন…', style: body(16, color: const Color(0xFF8A9690)))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: _busy ? null : _micTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: C.green,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF5FD3AE).withValues(alpha: _listening ? 0.25 : 0.12), spreadRadius: 10)],
                        ),
                        child: Center(
                          child: _listening
                              ? Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)))
                              : const Icon(Icons.mic_none_rounded, color: Colors.white, size: 34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(label, style: body(13, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Wave extends AnimatedWidget {
  const _Wave({required Animation<double> animation}) : super(listenable: animation);

  static const List<double> _base = [10, 18, 30, 44, 26, 50, 34, 20, 40, 52, 28, 16, 32, 22, 12];

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      height: 54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _base.length; i++)
            Container(
              width: 5,
              height: max(6.0, _base[i] * (0.55 + 0.45 * sin(2 * pi * t + i * 0.7).abs())),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(color: const Color(0xFF5FD3AE), borderRadius: BorderRadius.circular(3)),
            ),
        ],
      ),
    );
  }
}
