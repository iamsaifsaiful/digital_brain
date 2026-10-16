import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/dictation.dart';
import '../services/trace.dart';
import '../logic/parser.dart' show yesNo, words, normalize;
import '../logic/suggest.dart';
import '../logic/bn.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../state/chat.dart';
import '../state/chat_archive.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import 'app_places.dart';
import 'assistant_settings.dart';
import 'calls_screen.dart';
import 'special_days_screen.dart';
import 'confirm_screen.dart';
import 'ledger_form_screen.dart';
import 'money_screens.dart';
import 'new_item_screen.dart';
import 'notes_screen.dart';
import 'docs_screen.dart';
import 'health_hub.dart';
import 'person_screen.dart';
import 'plan_screens.dart';
import 'vault_item_screen.dart';
import '../logic/lang.dart';

/// সহকারী: speak or type; it keeps, finds and answers. Opened from the
/// mic beside the box at the bottom of every page ([listen] starts the
/// microphone), or with something already typed ([firstMessage]).
class ChatHome extends StatefulWidget {
  const ChatHome({super.key, this.listen = false, this.firstMessage});
  final bool listen;
  final String? firstMessage;

  @override
  State<ChatHome> createState() => ChatHomeState();
}

class ChatHomeState extends State<ChatHome> with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  final _scaffold = GlobalKey<ScaffoldState>();
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final Brain _brain = BrainScope.read(context);
  late final ChatArchive _archive = ChatArchive(_brain.services.lock.keys);
  late ChatController _chat = _make();

  /// The conversation (for tests).
  @visibleForTesting
  ChatController get chat => _chat;
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  List<SavedChat> _past = const [];

  /// Questions asked often, as one-tap chips above the text box; the user
  /// can add their own and remove any (kept in `quick_questions`).
  List<String> get _questions => _brain.quickQuestions;
  String _chatId = '';
  int _savedCount = 0;
  Future<void> _saving = Future.value();

  String _live = '';
  String? _error;
  bool _voice = false;
  bool _listening = false;

  /// The recogniser has really started (until then: "প্রস্তুত হচ্ছে…").
  bool _ready = false;

  // ── Long speech, said in several breaths ──
  // Each piece the recogniser finishes is kept in [_draft] (shown on screen,
  // never replaced by the next piece). Nothing is acted on until the user
  // says it is all ("বলা শেষ", or "না" to "আর কিছু বলতে চান?").

  /// The pieces said so far, in order.
  final _draft = <String>[];

  /// "আর কিছু বলতে চান?" was asked; the next answer is about that.
  bool _askingMore = false;

  /// Stopped and waiting for a button ("আরও বলব" / "বলা শেষ").
  bool _paused = false;

  /// "শেষ" was tapped while listening: the last piece completes the speech.
  bool _finishTap = false;

  /// Quiet after a piece: asks "আর কিছু বলতে চান?" when it fires.
  Timer? _moreTimer;

  /// The whole speech was sent (guards a double tap).
  bool _submitting = false;

  /// When a choice (হ্যাঁ / না …) was last tapped: the same answer heard by
  /// voice right after is the same answer, not a second one.
  DateTime _tappedAt = DateTime(2000);

  /// The recogniser's other guesses for the last piece.
  List<String> _pieceAlts = const [];
  bool _speaking = false;
  bool _busy = false;

  /// Away on another screen: do not listen meanwhile.
  bool _away = false;
  int _gen = 0;
  int _doneGen = -1;
  int _silences = 0;

  static final _suggestions = [
    (tr('টাকা দিলাম'), tr('রবিনকে ৫০০০ টাকা ধার দিলাম')),
    (tr('মনে করাও'), tr('কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও')),
    (tr('কাজের তালিকা'), tr('আজকের কাজের তালিকা')),
    (tr('জিজ্ঞেস করুন'), tr('এই মাসে কত খরচ হলো?')),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadPast();
      await _restoreDraft();
      if (!mounted) return;
      final first = widget.firstMessage?.trim() ?? '';
      if (first.isNotEmpty) {
        _send(first);
      } else if (widget.listen) {
        startVoice();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _undoTimer?.cancel();
    _moreTimer?.cancel();
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

  ChatController _make([List<ChatMessage> restored = const []]) {
    // A new conversation id for the trace (one conversation, many recogniser sessions).
    Trace.conversation = 'c${DateTime.now().millisecondsSinceEpoch % 1000000}';
    Trace.log('chat', 'conversation started', {'restored messages': restored.length});
    return ChatController(_brain, restored: restored)..addListener(_changed);
  }

  Future<void> _loadPast() async {
    final p = await _archive.load();
    if (mounted) setState(() => _past = p);
  }

  Future<void> _saveQuestions(List<String> q) => _brain.setQuickQuestions(q);

  Future<void> _addQuestion() async {
    final c = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('নতুন প্রশ্ন'), style: body(18, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('যে প্রশ্ন প্রায়ই করেন, লিখে রাখুন — এক চাপে জিজ্ঞেস করা যাবে।'), style: body(14, color: C.muted, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            style: body(16),
            decoration: InputDecoration(hintText: tr('যেমন: রহিমের কাছে কত পাব?')),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাদ দিন'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green))),
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
        title: Text(tr('প্রশ্নটা সরাবেন?'), style: body(18, weight: FontWeight.w600)),
        content: Text('“$q”', style: body(15, color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('না'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('সরান'), style: body(15, weight: FontWeight.w600, color: C.red))),
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
              shape: StadiumBorder(side: BorderSide(color: C.inputBorder)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _addQuestion,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 18, color: C.green),
                    const SizedBox(width: 4),
                    Text(tr('প্রশ্ন যোগ'), style: body(14, weight: FontWeight.w600, color: C.green)),
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
        title: Text(tr('এই কথাটা মুছবেন?'), style: body(18, weight: FontWeight.w600)),
        content: Text('“${c.title}”', style: body(15, color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('না'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('মুছুন'), style: body(15, weight: FontWeight.w600, color: C.red))),
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
    // "আমি শুনছি" is said while the microphone is already open: people start
    // talking as soon as they tap, and talking over it stops it — nothing is lost.
    await voice.stopSpeaking();
    if (mounted && _voice && !_listening && !_busy) unawaited(_listen(say: tr('আমি শুনছি')));
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

  /// Listens; [say] is spoken meanwhile (the user may talk over it).
  Future<void> _listen({String? say, bool? short}) async {
    if (!mounted || _away || _busy || !_voice) return;
    final voice = _brain.services.voice;
    final gen = ++_gen;
    setState(() {
      _live = '';
      _error = null;
      _listening = true;
      _ready = false;
      _speaking = say != null && !voice.muted;
    });
    unawaited(_wave.repeat());
    await voice.listen(
      short: short ?? _chat.expectsShortAnswer,
      say: say,
      onReady: () {
        if (!mounted || gen != _gen) return;
        setState(() => _ready = true);
        // Collecting a long speech and the user is quiet: ask once more.
        if (_draft.isNotEmpty && !_askingMore) {
          _moreTimer?.cancel();
          _moreTimer = Timer(const Duration(milliseconds: 1500), () {
            if (mounted && gen == _gen && _listening && _live.trim().isEmpty) _quietAfterSpeech();
          });
        }
      },
      onSaid: () {
        if (mounted && _speaking) setState(() => _speaking = false);
      },
      onWords: (w) {
        if (!mounted || gen != _gen) return;
        if (w.trim().isNotEmpty) _moreTimer?.cancel();
        setState(() => _live = w);
      },
      onDone: (w) {
        // One sentence is handled once, even if the recogniser reports it twice.
        if (!mounted || gen != _gen || _doneGen == gen) return;
        _doneGen = gen;
        _wave.stop();
        setState(() {
          _listening = false;
          _live = '';
        });
        _moreTimer?.cancel();
        if (w.trim().isEmpty && (_askingMore || _draft.isNotEmpty)) {
          // Quiet after the question (or while collecting): never taken as
          // "yes" or "no" — stop and wait for a button.
          if (_askingMore || _draft.isNotEmpty) {
            if (_askingMore) {
              setState(() {
                _askingMore = false;
                _paused = true;
              });
            } else {
              _quietAfterSpeech();
            }
            return;
          }
        }
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
            setState(() => _error = tr('অনেকক্ষণ কিছু শুনিনি, তাই মাইক বন্ধ রাখলাম। বলতে চাইলে “বলুন” চাপুন।'));
          }
        } else {
          _silences = 0;
          _heardPiece(w);
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
          setState(() => _error = trf('{0} “বলুন” চাপলে আবার শুনব।', [m]));
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _gen++;
    _wave.stop();
    final was = _listening;
    if (mounted) setState(() => _listening = _speaking = false);
    if (was) await _brain.services.voice.cancel();
  }

  /// "শেষ" / "বলুন" in the voice view.
  void _voiceMain() {
    if (_busy) return;
    if (_listening) {
      // Finish what was heard so far.
      _finishTap = true;
      _brain.services.voice.stop();
    } else if (_draft.isNotEmpty) {
      _submitDraft();
    } else if (_chat.hasPending) {
      _flush();
    } else {
      _brain.services.voice.stopSpeaking();
      _silences = 0;
      _chat.ended = false;
      _listen();
    }
  }

  /// Quiet after speaking: "আর কিছু বলতে চান?".
  Future<void> _quietAfterSpeech() async {
    // Quiet is not "done": the user is asked, and nothing is acted on until
    // they say it is all (or tap a button).
    await _askMore();
  }

  /// A piece of speech the recogniser finished.
  void _heardPiece(String w) {
    final finishTap = _finishTap;
    _finishTap = false;
    // "হ্যাঁ" heard just after the same answer was tapped: already answered.
    if (yesNo(w) != null && words(normalize(w)).length <= 2 && DateTime.now().difference(_tappedAt) < const Duration(milliseconds: 2500)) {
      _keepListening();
      return;
    }
    // An answer the chat asked for, or a quick request, goes at once.
    if (_draft.isEmpty && !_askingMore && (_chat.waiting || _chat.quickRequest(w))) {
      _send(w);
      return;
    }
    if (_askingMore) {
      _askingMore = false;
      final (kind, content) = continuationOf(w);
      Trace.log('speech', 'answer to আর কিছু', {'heard': w, 'means': kind.name});
      switch (kind) {
        case Continue.finish:
          _submitDraft();
          return;
        case Continue.cancel:
          _dropDraft(tr('ঠিক আছে, পুরো কথাটা বাদ দিলাম।'));
          return;
        case Continue.more:
          _keepListening();
          return;
        case Continue.content:
          // "হ্যাঁ, বাজারে ৭০০ টাকা, আর কিছু বলার নেই": add, then it is done.
          final (body, done) = splitDoneTail(content);
          if (body.isNotEmpty) _addPiece(body);
          if (finishTap || done) {
            unawaited(_submitDraft());
            return;
          }
          _keepListening();
          return;
      }
    }
    if (_draft.isNotEmpty && endsSpeech(w)) {
      _submitDraft();
      return;
    }
    // "…৫০০০ টাকা দিলাম, না আর বলতে চাই না": the words before are kept and
    // the whole speech goes at once — the closing words are not content.
    final (body, done) = splitDoneTail(w);
    if (done) {
      Trace.log('speech', 'closing words heard', {'kept': body});
      if (body.isNotEmpty) _addPiece(body);
      if (_draft.isNotEmpty) {
        unawaited(_submitDraft());
      } else {
        unawaited(_stopListening());
      }
      return;
    }
    _addPiece(w);
    if (finishTap) {
      unawaited(_submitDraft());
      return;
    }
    _keepListening();
  }

  void _addPiece(String w) {
    Trace.log('speech', 'piece kept', {'n': _draft.length + 1, 'piece': w, 'before': assemble(_draft)});
    final v = _brain.services.voice;
    // The recogniser's other guesses for this piece (used when the speech is one piece).
    _pieceAlts = v.lastHeard.trim() == w.trim() ? v.lastAlternatives : const [];
    setState(() {
      _draft.add(w.trim());
      _paused = false;
    });
    unawaited(_saveDraft());
  }

  void _keepListening() {
    setState(() => _paused = false);
    if (mounted && _voice && !_away) unawaited(_listen());
  }

  /// "আর কিছু বলতে চান?" — said before the microphone opens again, so the
  /// question never becomes part of the speech.
  Future<void> _askMore() async {
    _moreTimer?.cancel();
    if (!mounted || _draft.isEmpty || _askingMore) return;
    await _stopListening();
    if (!mounted) return;
    setState(() => _askingMore = true);
    Trace.log('speech', 'asked: আর কিছু বলতে চান?', {'so far': assemble(_draft)});
    await _listen(say: tr('আর কিছু বলতে চান?'), short: true);
  }

  /// "বলা শেষ": the whole speech, once.
  Future<void> _submitDraft() async {
    if (_submitting || _draft.isEmpty) return;
    _submitting = true;
    _moreTimer?.cancel();
    final whole = assemble(_draft);
    Trace.log('speech', 'whole speech sent', {'pieces': _draft.length, 'text': whole});
    if (_draft.length == 1) {
      final v = _brain.services.voice;
      v.lastHeard = whole;
      v.lastAlternatives = _pieceAlts;
    }
    setState(() {
      _draft.clear();
      _askingMore = false;
      _paused = false;
    });
    unawaited(_saveDraft());
    try {
      await _send(whole);
    } finally {
      _submitting = false;
    }
  }

  void _dropDraft(String say) {
    _moreTimer?.cancel();
    setState(() {
      _draft.clear();
      _askingMore = false;
      _paused = false;
    });
    unawaited(_saveDraft());
    _chat.addInfo(say);
    unawaited(_brain.services.voice.speak(say));
  }

  /// The unfinished speech is kept (locked, on this phone) so a crash or a
  /// closed app does not lose it; cleared once sent or dropped.
  Future<void> _saveDraft() async {
    try {
      final keys = _brain.services.lock.keys;
      await keys.write('voice_draft', _draft.join('\n'));
      await keys.write('voice_draft_at', _draft.isEmpty ? '' : DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Speech left unfinished last time (the app was closed or crashed): put
  /// in the box to check and send — never acted on by itself.
  Future<void> _restoreDraft() async {
    try {
      final keys = _brain.services.lock.keys;
      final left = (await keys.read('voice_draft') ?? '').trim();
      if (left.isEmpty || !mounted) return;
      final at = DateTime.tryParse(await keys.read('voice_draft_at') ?? '');
      await keys.write('voice_draft', '');
      await keys.write('voice_draft_at', '');
      // Only speech cut off a little while ago is worth bringing back; an
      // old one would just be in the way.
      if (at != null && DateTime.now().difference(at) > const Duration(minutes: 30)) return;
      final text = left.split('\n').join(' ');
      _text.text = text;
      _text.selection = TextSelection.collapsed(offset: text.length);
      // Opened to talk: the box is not on screen, so a line about it would
      // only cover the voice view. It waits quietly in the box.
      if (widget.listen) return;
      _chat.addInfo(tr('আগের বার বলা অসম্পূর্ণ কথাটা লেখার ঘরে রাখা আছে — দেখে পাঠান, বা মুছে দিন।'));
    } catch (_) {}
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
    _chat.voiceMode = _voice;
    try {
      say = await _chat.hear(said);
    } catch (e) {
      debugPrint('chat failed: $e');
      say = tr('দুঃখিত, একটু সমস্যা হলো। আরেকবার বলবেন?');
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
    // The usual case: answer aloud while already listening, so the user can
    // cut in ("থামো", the next question) and every word is heard.
    final plain = _chat.pendingLaunch == null && _chat.openNow == null && !_chat.ended;
    if (_voice && say.isNotEmpty && plain && !_away) {
      _silences = 0;
      if (!_listening) await _listen(say: say);
      return;
    }
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
    final place = _chat.openNow;
    if (place != null) {
      _chat.openNow = null;
      await _openPlace(place);
      return;
    }
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

  Future<void> _openVault(VaultItem v) async {
    _away = true;
    await _stopListening();
    if (!mounted) return;
    final ok = await verifyUser(context, reason: trf('{0} — তথ্য দেখতে যাচাই করুন', [v.name]));
    _away = false;
    if (ok && mounted) await _open(VaultItemScreen(id: v.id));
  }

  /// A part of the app ("নোট খোলো"): a page on top of the chat, or a main tab
  /// (the chat closes).
  Future<void> _openPlace(ChatLink l) async {
    // "বদলান: …" — the thing's own edit page.
    if (l.page!.startsWith('edit:')) {
      final d = _brain.data;
      final id = l.folder ?? '';
      if (l.page == 'edit:doc') {
        await _openDoc(id, l.label);
        return;
      }
      final Widget? w = switch (l.page) {
        'edit:reminder' => d.reminders.where((x) => x.id == id).map((r) => NewItemScreen(reminder: r)).firstOrNull,
        'edit:note' => d.notes.where((x) => x.id == id).map((n) => NewItemScreen(note: n)).firstOrNull,
        'edit:contact' => d.contacts.where((x) => x.id == id).map((c) => NewItemScreen(contact: c)).firstOrNull,
        'edit:ledger' => d.ledger.where((x) => x.id == id).map((e) => LedgerFormScreen(entry: e)).firstOrNull,
        'edit:cash' => d.cash.where((x) => x.id == id).map((e) => CashFormScreen(entry: e)).firstOrNull,
        _ => placePage(switch (l.page) {
            'edit:task' => 'tasks',
            'edit:special' => 'special',
            'edit:medicine' => 'medicines',
            'edit:habit' => 'habits',
            'edit:memory' => 'memory',
            _ => 'home',
          }),
      };
      if (w != null) await _open(w);
      return;
    }
    final page = placePage(l.page!, folder: l.folder);
    if (page != null) {
      await _open(page);
      return;
    }
    _away = true;
    await _stopListening();
    unawaited(_brain.services.voice.stopSpeaking());
    if (mounted) await openPlace(context, l.page!, folder: l.folder);
  }

  Future<void> _openDoc(String id, String label) async {
    _away = true;
    await _stopListening();
    if (!mounted) return;
    final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [label]));
    _away = false;
    if (ok && mounted) await _open(DocScreen(id: id, unlocked: true));
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
      case LinkKind.special:
        _open(const SpecialDaysScreen());
      case LinkKind.memory:
        _open(const MemoryScreen());
      case LinkKind.doc:
        _openDoc(l.docId!, l.label);
      case LinkKind.health:
        _open(const HealthScreen());
      case LinkKind.page:
        _openPlace(l);
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
    return PopScope(
      canPop: !_voice,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeVoice();
      },
      child: Scaffold(
        key: _scaffold,
        backgroundColor: C.surface,
        body: SafeArea(
          child: _voice
              ? _voiceView()
              : Column(children: [
                  _topBar(),
                  Expanded(child: _chat.started ? _conversation() : _welcome()),
                  if (_chat.choices.isNotEmpty) _choiceRow() else _questionRow(),
                  _composer(),
                ]),
        ),
      ),
    );
  }

  Widget _topBar() {
    final title = _chat.started ? chatTitle(_chat.messages) : tr('সহকারী');
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _chat.started ? C.line2 : Colors.transparent))),
      child: Row(children: [
        IconButton(
          tooltip: tr('ফিরে যান'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.chevron_left_rounded, size: 30, color: C.ink),
        ),
        Expanded(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(17, weight: FontWeight.w600)),
        ),
        IconButton(
          tooltip: tr('আগের কথা'),
          onPressed: _showPast,
          icon: Icon(Icons.history_rounded, size: 24, color: C.ink),
        ),
        IconButton(
          tooltip: tr('নতুন কথা'),
          onPressed: _chat.started ? newChat : null,
          icon: Icon(Icons.edit_square, size: 22, color: _chat.started ? C.ink : C.inputBorder),
        ),
      ]),
    );
  }

  Future<void> _showPast() async {
    _focus.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PastSheet(
        past: _past,
        currentId: _chatId,
        onNew: () {
          Navigator.of(ctx).pop();
          newChat();
        },
        onPast: (c) {
          Navigator.of(ctx).pop();
          _openPast(c);
        },
        onDeletePast: (c) {
          Navigator.of(ctx).pop();
          _deletePast(c);
        },
      ),
    );
  }

  Widget _welcome() {
    Widget suggestion((String, String) s) => Expanded(
          child: Material(
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: C.line)),
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

    Widget can(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(icon, size: 19, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: body(14.5, color: C.muted2))),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: _Mark(size: 44)),
        const SizedBox(height: 14),
        Text(tr('আপনার সহকারী'), style: display(26, weight: 700, height: 1.2)),
        Text(tr('বলুন বা লিখুন — রেখে দেবো, খুঁজে দেবো, উত্তর দেবো'), style: body(15.5, color: C.muted, height: 1.45)),
        const SizedBox(height: 10),
        can(Icons.bookmark_add_outlined, tr('রাখা: টাকা, কাজ, রিমাইন্ডার, নোট, নম্বর, পাসওয়ার্ড')),
        can(Icons.search_rounded, tr('খোঁজা: “রহিমের নম্বর কত?”, “গাড়ির কাগজ কোথায়?”')),
        can(Icons.chat_bubble_outline_rounded, tr('জিজ্ঞেস করা: “আজ কী কী আছে?”, “এ মাসে কত খরচ হলো?”')),
        const SizedBox(height: 20),
        Text(tr('যেমন বলতে পারেন'), style: body(13, weight: FontWeight.w600, color: C.muted)),
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
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.green)),
                const SizedBox(width: 8),
                Text(tr('ভাবছি…'), style: body(14, color: C.muted)),
              ]),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, textAlign: TextAlign.center, style: body(13, color: C.orangeDark, height: 1.4)),
            ),
        ],
      );

  /// The words were heard wrong: put them in the box to fix and send again.
  void _editAgain(String text) {
    _closeVoice();
    _text.text = text;
    _text.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  Widget _message(ChatMessage m) {
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => _editAgain(m.text),
          child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8, left: 56),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: C.soft,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(m.text, style: body(16, height: 1.45)),
          ),
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
                  if (i > 0) Divider(height: 1, color: C.line2),
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
                        Icon(Icons.lock_outline_rounded, color: C.blue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(v.name, style: body(15, weight: FontWeight.w600))),
                        Text(tr('খুলুন'), style: body(14, color: C.green, weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
          if (m.undoable(DateTime.now())) _undoButton(m),
          if (m.links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in m.links)
                  Material(
                    color: C.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: C.line)),
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

  Timer? _undoTimer;

  /// "ফিরিয়ে নিন" for a few seconds after something is saved.
  Widget _undoButton(ChatMessage m) {
    _undoTimer?.cancel();
    final left = ChatMessage.undoFor - DateTime.now().difference(m.undoAt!);
    _undoTimer = Timer(left.isNegative ? Duration.zero : left, () {
      if (mounted) setState(() {});
    });
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _chat.undo(m),
        icon: Icon(Icons.undo_rounded, size: 18, color: C.orange),
        label: Text(tr('ফিরিয়ে নিন'), style: body(14, weight: FontWeight.w600, color: C.orange)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: C.orange.withValues(alpha: 0.5)), shape: const StadiumBorder(), visualDensity: VisualDensity.compact),
      ),
    );
  }

  Widget _chip(ChatChoice c) {
    final yes = c.answer == 'হ্যাঁ';
    return ActionChip(
      label: Text(c.label, style: body(15, weight: FontWeight.w600, color: yes ? C.onInk : C.ink)),
      // Explicit colours for every state: in the dark look the theme's own
      // pressed/hover/disabled shades made the text unreadable.
      color: WidgetStateProperty.resolveWith((states) {
        final base = yes ? C.ink : C.surface;
        if (states.contains(WidgetState.disabled)) return base.withValues(alpha: 0.55);
        if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return Color.lerp(base, yes ? C.surface : C.ink, 0.14);
        }
        return base;
      }),
      side: yes ? BorderSide.none : BorderSide(color: C.inputBorder),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onPressed: _busy
          ? null
          : () {
              _tappedAt = DateTime.now();
              _send(c.answer);
            },
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

  /// Sentences for what is being typed ("বিদ্যুৎ বিল" → remind, spend, to-do…).
  Widget _typingHints() => ValueListenableBuilder<TextEditingValue>(
        valueListenable: _text,
        builder: (context, v, _) {
          final ps = _busy ? const <String>[] : suggestPrompts(v.text, _brain.data);
          if (ps.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 6),
              children: [
                for (final p in ps)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: ValueKey('suggest:$p'),
                      avatar: Icon(Icons.auto_awesome_outlined, size: 16, color: C.green),
                      label: Text(p.trim(), style: body(14)),
                      backgroundColor: C.surface,
                      side: BorderSide(color: C.inputBorder),
                      shape: const StadiumBorder(),
                      onPressed: () {
                        _text.text = p;
                        _text.selection = TextSelection.collapsed(offset: p.length);
                        _focus.requestFocus();
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _composer() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _typingHints(),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.inputBorder),
              boxShadow: const [BoxShadow(color: Color(0x0F111827), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _Round(icon: Icons.add_rounded, tooltip: tr('দ্রুত যোগ'), bg: C.soft, fg: C.ink, size: 40, onTap: _quickAdd),
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
                    hintText: tr('লিখুন বা কথা বলুন…'),
                    hintStyle: body(16, color: C.muted),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, v, _) => v.text.trim().isEmpty
                    ? _Round(icon: Icons.mic_none_rounded, tooltip: tr('কথা বলুন'), bg: C.green, fg: Colors.white, size: 44, onTap: startVoice)
                    : _Round(icon: Icons.arrow_upward_rounded, tooltip: tr('পাঠান'), bg: C.ink, fg: Colors.white, size: 44, onTap: _busy ? null : _submitTyped),
              ),
            ]),
          ),
          if (!_chat.started)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_brain.aiOn ? tr('পাসওয়ার্ড ও নম্বর ফোনেই থাকে · AI চালু: আপনার কথা Anthropic-এ যায়') : tr('হিসাব আর পাসওয়ার্ড শুধু আপনার ফোনেই থাকে'), style: body(12, color: C.muted), textAlign: TextAlign.center),
            ),
        ]),
      );

  /// Talking: a big breathing circle, what is being heard, and the last
  /// answer with its buttons.
  Widget _voiceView() {
    final msgs = _chat.messages;
    final lastUser = msgs.lastIndexWhere((m) => m.fromUser);
    final replies = [for (final m in msgs.skip(lastUser + 1)) if (!m.fromUser) m];
    final status = _askingMore && !_listening
        ? tr('আর কিছু বলতে চান?')
        : _paused
        ? tr('থেমে আছি — আরও বলবেন, নাকি বলা শেষ?')
        : _listening && _speaking
        ? tr('বলছি — আপনি কথা বললেই থেমে শুনবো')
        : _listening
        ? (_ready ? tr('শুনছি…') : tr('প্রস্তুত হচ্ছে… একটু পরে বলুন'))
        : (_busy || _chat.thinking)
            ? tr('ভাবছি…')
            : _speaking
                ? tr('বলছি…')
                : tr('মাইক বন্ধ');
    final hint = _chat.collecting ? tr('বলে যান — তালিকা শেষ হলে “শেষ” বলুন।') : tr('বলে যান — থামলে আমি বুঝে নেব।');
    return Column(children: [
      const SizedBox(height: 14),
      Text(status, style: body(14, color: C.muted)),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          children: [
            Center(child: _Orb(animation: _wave, active: _listening || _speaking)),
            const SizedBox(height: 28),
            if (_draft.isNotEmpty) ...[
              // Everything said so far stays; what is being said now is lighter.
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: assemble(_draft), style: body(19, weight: FontWeight.w500, height: 1.55)),
                  if (_listening && _live.trim().isNotEmpty) TextSpan(text: ' ${_live.trim()}', style: body(19, color: C.muted, height: 1.55)),
                ]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                if (!_listening)
                  ActionChip(
                    key: const Key('speech-more'),
                    avatar: Icon(Icons.mic_none_rounded, size: 18, color: C.green),
                    label: Text(tr('আরও বলব'), style: body(15, weight: FontWeight.w600)),
                    onPressed: _busy ? null : () => setState(() {
                      _askingMore = false;
                      _keepListening();
                    }),
                  ),
                ActionChip(
                  key: const Key('speech-done'),
                  avatar: Icon(Icons.send_rounded, size: 18, color: C.onInk),
                  label: Text(tr('শেষ করেছি'), style: body(15, weight: FontWeight.w600, color: C.onInk)),
                  color: WidgetStatePropertyAll(C.ink),
                  onPressed: _busy ? null : () async {
                    if (_listening) {
                      _finishTap = true;
                      await _brain.services.voice.stop();
                    } else {
                      await _submitDraft();
                    }
                  },
                ),
                ActionChip(
                  key: const Key('speech-cancel'),
                  label: Text(tr('বাতিল'), style: body(15, color: C.red)),
                  onPressed: _busy ? null : () async {
                    await _stopListening();
                    _dropDraft(tr('ঠিক আছে, পুরো কথাটা বাদ দিলাম।'));
                  },
                ),
              ]),
            ] else if (_listening && _live.isNotEmpty)
              Text(_live, textAlign: TextAlign.center, style: body(20, weight: FontWeight.w500, height: 1.5))
            else if (lastUser >= 0 && !_listening) ...[
              Text('“${msgs[lastUser].text}”', textAlign: TextAlign.center, style: body(16, color: C.muted, height: 1.5)),
              Center(
                child: TextButton.icon(
                  onPressed: () => _editAgain(msgs[lastUser].text),
                  icon: Icon(Icons.edit_outlined, size: 16, color: C.green),
                  label: Text(tr('ভুল শুনেছি? ঠিক করুন'), style: body(13.5, weight: FontWeight.w600, color: C.green)),
                ),
              ),
            ],
            if (_draft.isEmpty && (!_listening || _live.isEmpty))
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
                        icon: Icon(Icons.lock_outline_rounded, size: 18, color: C.blue),
                        label: Text(v.name, style: body(15, weight: FontWeight.w600)),
                      ),
                    ),
                  if (m.undoable(DateTime.now())) Center(child: _undoButton(m)),
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
          _Round(icon: Icons.keyboard_alt_outlined, tooltip: tr('লিখে বলুন'), bg: C.soft, fg: C.ink, size: 56, onTap: _typeInstead),
          const SizedBox(width: 24),
          Semantics(
            button: true,
            label: _listening ? (_draft.isNotEmpty ? tr('বলা শেষ') : tr('শেষ')) : (_draft.isNotEmpty ? tr('পাঠান') : tr('বলুন')),
            excludeSemantics: true,
            child: Material(
              color: C.fill,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _busy ? null : _voiceMain,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Center(
                        child: Text(_listening ? (_draft.isNotEmpty ? tr('বলা শেষ') : tr('শেষ')) : (_draft.isNotEmpty ? tr('পাঠান') : tr('বলুন')),
                            style: body(17, weight: FontWeight.w600, color: Colors.white))),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          _Round(icon: Icons.close_rounded, tooltip: tr('বন্ধ করুন'), bg: C.soft, fg: C.ink, size: 56, onTap: _closeVoice),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFF34B48E), C.green, C.greenDark], stops: [0, 0.6, 1]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// "আগের কথা": earlier conversations, kept only on this phone.
class _PastSheet extends StatelessWidget {
  const _PastSheet({required this.past, required this.currentId, required this.onNew, required this.onPast, required this.onDeletePast});

  final List<SavedChat> past;
  final String currentId;
  final VoidCallback onNew;
  final void Function(SavedChat) onPast;
  final void Function(SavedChat) onDeletePast;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(tr('আগের কথা'), style: body(17, weight: FontWeight.w600))),
                TextButton.icon(
                  onPressed: onNew,
                  icon: Icon(Icons.edit_square, size: 18, color: C.green),
                  label: Text(tr('নতুন কথা'), style: body(14, weight: FontWeight.w600, color: C.green)),
                ),
              ]),
              const SizedBox(height: 4),
              if (past.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(tr('এখনো কিছু নেই। আগের কথাগুলো শুধু এই ফোনে থাকে।'), style: body(14, color: C.muted, height: 1.4)),
                )
              else
                Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    for (final c in past)
                      Material(
                        color: c.id == currentId ? C.soft : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onPast(c),
                          onLongPress: () => onDeletePast(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            child: Row(children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 18, color: C.muted),
                              const SizedBox(width: 10),
                              Expanded(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, color: C.muted2))),
                              Text('${bnDigits(c.at.day)} ${monthShort(c.at.month)}', style: body(12, color: C.muted)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 6),
              Text(tr('শুধু এই ফোনে থাকে · মুছতে চেপে ধরে রাখুন'), textAlign: TextAlign.center, style: body(12, color: C.muted)),
            ]),
          ),
        ),
      );
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
          Text(tr('ফর্মে যোগ করুন'), style: body(16, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: tile(0, Icons.notifications_none_rounded, tr('কাজ / রিমাইন্ডার'), C.orange, C.orangeTint)),
            const SizedBox(width: 8),
            Expanded(child: tile(1, Icons.payments_outlined, tr('ধার-দেনা'), C.green, C.greenTint)),
            const SizedBox(width: 8),
            Expanded(child: tile(2, Icons.account_balance_wallet_outlined, tr('খরচ / আয়'), C.green, C.greenTint)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: tile(3, Icons.sticky_note_2_outlined, tr('নোট'), C.blue, C.blueTint)),
            const SizedBox(width: 8),
            Expanded(child: tile(4, Icons.lock_outline_rounded, tr('পাসওয়ার্ড'), C.ink, C.soft)),
            const SizedBox(width: 8),
            Expanded(child: tile(5, Icons.call_outlined, tr('নম্বর রাখুন'), C.ink, C.soft)),
          ]),
          const SizedBox(height: 12),
          Material(
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: C.line)),
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
                    child: Icon(Icons.download_rounded, color: C.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('ফোনবুক থেকে নম্বর আনুন'), style: body(15, weight: FontWeight.w600)),
                      Text(tr('এক চাপে সব, একই নম্বর দুবার আসবে না'), style: body(12, color: C.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(tr('টিপস: ফর্ম না খুলে সরাসরি লিখে বা বলেও দিতে পারেন — “বাজারে ৫০০ টাকা খরচ”।'), style: body(13, color: C.muted, height: 1.5)),
        ]),
      ),
    );
  }
}
