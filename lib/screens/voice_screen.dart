import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/parser.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'answer_screen.dart';
import 'balance_set_screen.dart';
import 'confirm_screen.dart';

/// Listens (or takes typed text), works out what was meant and opens the
/// right next step.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key, this.startTyping = false});
  final bool startTyping;

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  final _text = TextEditingController();
  final _focus = FocusNode();
  String _words = '';
  String? _error;
  bool _listening = false;
  bool _typing = false;
  bool _handled = false;

  static const _examples = [
    'সজীবকে ৫০০ টাকা দিলাম',
    'সজীবের কাছে আমার কত টাকা পাওনা?',
    'ডোমেইন রিনিউ করার তারিখটা মনে করিয়ে দাও',
    'আমার Wi-Fi-এর নাম কী?',
    'ABC ওয়েবসাইটের লগইন তথ্য দেখাও',
    'ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই',
    'মনে রাখো: গাড়ির কাগজ আলমারির উপরের তাকে',
  ];

  @override
  void initState() {
    super.initState();
    _typing = widget.startTyping;
    if (!_typing) WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _wave.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    final voice = BrainScope.read(context).services.voice;
    setState(() {
      _words = '';
      _error = null;
      _listening = true;
      _handled = false;
    });
    _wave.repeat();
    await voice.listen(
      onWords: (w) {
        if (mounted) setState(() => _words = w);
      },
      onDone: (w) {
        if (!mounted) return;
        _wave.stop();
        setState(() {
          _listening = false;
          _words = w;
        });
        if (w.trim().isEmpty) {
          setState(() => _error = 'কিছু শুনতে পাইনি। আবার বলুন বা লিখে দিন।');
        } else {
          _handle(w);
        }
      },
      onError: (m) {
        if (!mounted) return;
        _wave.stop();
        setState(() {
          _listening = false;
          _error = m;
        });
      },
    );
  }

  Future<void> _stop() async {
    await BrainScope.read(context).services.voice.stop();
  }

  Future<void> _handle(String said) async {
    if (_handled) return;
    _handled = true;
    final brain = BrainScope.read(context);
    final cmd = Parser(ledger: brain.data.ledger).parse(said);
    final nav = Navigator.of(context);
    switch (cmd) {
      case LedgerAdd():
        unawaited(nav.pushReplacement(MaterialPageRoute(builder: (_) => ConfirmScreen(command: cmd))));
      case LedgerSet():
        unawaited(nav.pushReplacement(MaterialPageRoute(builder: (_) => BalanceSetScreen(command: cmd))));
      case NotUnderstood():
        _handled = false;
        setState(() => _error = 'ঠিক বুঝতে পারিনি। নিচের মতো করে বলে দেখুন।');
      default:
        unawaited(nav.pushReplacement(MaterialPageRoute(builder: (_) => AnswerScreen(command: cmd))));
    }
  }

  void _toggleTyping() {
    final voice = BrainScope.read(context).services.voice;
    if (_listening) voice.cancel();
    _wave.stop();
    setState(() {
      _typing = !_typing;
      _listening = false;
      _error = null;
    });
    if (_typing) {
      _focus.requestFocus();
    } else {
      _listen();
    }
  }

  void _submitTyped() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _handled = false;
    setState(() => _words = t);
    _handle(t);
  }

  @override
  Widget build(BuildContext context) {
    final showWords = _words.isNotEmpty ? _words : (_listening ? '' : '');
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) BrainScope.read(context).services.voice.cancel();
      },
      child: Scaffold(
        backgroundColor: C.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Row(
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
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3A4842)), borderRadius: BorderRadius.circular(999)),
                      child: Text('ভাষা: বাংলা', style: body(14, color: C.onDarkMuted)),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_listening)
                          Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: const Color(0xFF5FD3AE), shape: BoxShape.circle, boxShadow: [
                                BoxShadow(color: const Color(0xFF5FD3AE).withValues(alpha: 0.25), spreadRadius: 6),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Text('শুনছি…', style: body(15, color: C.mint, weight: FontWeight.w600)),
                          ]),
                        if (_listening) ...[
                          const SizedBox(height: 6),
                          Text('বলা শেষ হলে ২ সেকেন্ড থামুন, অথবা নিচের বোতাম চাপুন', style: body(13, color: const Color(0xFFA9B5AF))),
                        ],
                        if (_typing)
                          Text('লিখে জিজ্ঞেস করুন বা যোগ করুন', style: body(15, color: C.mint, weight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        if (_typing)
                          TextField(
                            controller: _text,
                            focusNode: _focus,
                            minLines: 2,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitTyped(),
                            style: body(20, color: Colors.white),
                            cursorColor: C.mint,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: C.dark2,
                              hintText: 'যেমন: রহিমের কাছ থেকে ১০০০ টাকা ধার নিয়েছি',
                              hintStyle: body(16, color: const Color(0xFF8A9690)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.mint, width: 2)),
                              suffixIcon: IconButton(
                                tooltip: 'পাঠান',
                                onPressed: _submitTyped,
                                icon: const Icon(Icons.arrow_upward_rounded, color: C.mint),
                              ),
                            ),
                          )
                        else
                          Text(
                            showWords.isEmpty ? (_listening ? 'বলুন…' : '') : showWords,
                            style: display(32, color: showWords.isEmpty ? const Color(0xFF8A9690) : Colors.white, height: 1.3),
                          ),
                        const SizedBox(height: 20),
                        if (_listening) _Wave(animation: _wave),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: body(16, color: C.peach, weight: FontWeight.w600, height: 1.5)),
                        ],
                        const SizedBox(height: 24),
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
                                  onTap: () {
                                    BrainScope.read(context).services.voice.cancel();
                                    _wave.stop();
                                    setState(() {
                                      _listening = false;
                                      _words = e;
                                      _handled = false;
                                    });
                                    _handle(e);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('“$e”', style: body(14, color: const Color(0xFFE4EAE7))),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _RoundAction(
                        icon: _typing ? Icons.mic_none_rounded : Icons.keyboard_alt_outlined,
                        label: _typing ? 'বলে যোগ' : 'লিখে যোগ',
                        onTap: _toggleTyping,
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: _listening ? 'বলা শেষ' : 'আবার শুনুন',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: _typing ? _submitTyped : (_listening ? _stop : _listen),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: C.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF5FD3AE).withValues(alpha: 0.14), spreadRadius: 10),
                                  ],
                                ),
                                child: Center(
                                  child: _typing
                                      ? const Icon(Icons.send_rounded, color: Colors.white, size: 32)
                                      : _listening
                                          ? Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)))
                                          : const Icon(Icons.mic_none_rounded, color: Colors.white, size: 36),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(_typing ? 'পাঠান' : (_listening ? 'বলা শেষ' : 'আবার শুনুন'), style: body(13, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: C.dark2, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 4),
              Text(label, style: body(13, color: C.onDarkMuted)),
            ],
          ),
        ),
      );
}

class _Wave extends AnimatedWidget {
  const _Wave({required Animation<double> animation}) : super(listenable: animation);

  static const List<double> _base = [14, 24, 40, 58, 34, 66, 46, 28, 52, 70, 38, 22, 44, 30, 18, 26, 12];

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _base.length; i++)
            Container(
              width: 6,
              height: max(8.0, _base[i] * (0.55 + 0.45 * sin(2 * pi * t + i * 0.7).abs())),
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: const Color(0xFF5FD3AE), borderRadius: BorderRadius.circular(3)),
            ),
        ],
      ),
    );
  }
}
