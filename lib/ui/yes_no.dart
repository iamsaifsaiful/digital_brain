import 'package:flutter/material.dart';

import '../logic/parser.dart';
import '../services/voice.dart';
import 'theme.dart';

/// Asks a question aloud, then listens for the spoken answer.
///
/// A screen keeps one of these, calls [ask], and gets [onAnswer] with what
/// was heard; [yesNo] in logic/parser.dart turns it into হ্যাঁ/না.
class SpokenQuestion extends ChangeNotifier {
  SpokenQuestion({required this.voice, required this.onAnswer});

  final Voice voice;
  final void Function(String heard) onAnswer;

  bool listening = false;
  String heard = '';

  /// Shown under the buttons ("বুঝিনি — হ্যাঁ বা না বলুন" etc.).
  String? hint;
  bool _disposed = false;

  Future<void> ask(String question) async {
    await voice.speakAndWait(question);
    await listen();
  }

  Future<void> listen() async {
    if (_disposed) return;
    listening = true;
    heard = '';
    hint = null;
    notifyListeners();
    await voice.listen(
      short: true,
      onWords: (w) {
        if (_disposed) return;
        heard = w;
        notifyListeners();
      },
      onDone: (w) {
        if (_disposed) return;
        listening = false;
        heard = w;
        notifyListeners();
        if (w.trim().isEmpty) {
          hint = 'কিছু শুনিনি। বোতাম চাপুন, বা মাইক চেপে “হ্যাঁ” / “না” বলুন।';
          notifyListeners();
        } else {
          onAnswer(w);
        }
      },
      onError: (_) {
        if (_disposed) return;
        listening = false;
        hint = 'বোতাম চাপুন, বা মাইক চেপে “হ্যাঁ” / “না” বলুন।';
        notifyListeners();
      },
    );
  }

  void stop() {
    if (listening) voice.cancel();
    listening = false;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

/// "শুনছি… হ্যাঁ বা না বলুন" strip with a mic button to listen again.
class ListeningStrip extends StatelessWidget {
  const ListeningStrip({super.key, required this.q, this.prompt = 'মুখে “হ্যাঁ” বা “না” বললেও হবে'});
  final SpokenQuestion q;
  final String prompt;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: q,
        builder: (context, _) {
          final text = q.listening
              ? (q.heard.isEmpty ? 'শুনছি… “হ্যাঁ” বা “না” বলুন' : '“${q.heard}”')
              : (q.hint ?? prompt);
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: q.listening ? C.greenTint : C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: q.listening ? C.green : C.line),
            ),
            child: Row(
              children: [
                Icon(q.listening ? Icons.graphic_eq_rounded : Icons.record_voice_over_outlined, color: C.green, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: body(14, color: q.listening ? C.greenDark : C.muted, weight: q.listening ? FontWeight.w600 : FontWeight.w400))),
                IconButton(
                  tooltip: q.listening ? 'শোনা বন্ধ করুন' : 'বলে উত্তর দিন',
                  onPressed: q.listening ? q.stop : q.listen,
                  icon: Icon(q.listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded, color: C.green),
                ),
              ],
            ),
          );
        },
      );
}

/// Picks one of [options] (or "expense") from a spoken answer to "এটা কোন
/// ধরনের লেনদেন?": "শোধ", "ফেরত", "নতুন ধার", "খরচ"…
String? pickSpokenOption(String heard, List<String> optionNames, {bool allowExpense = false}) {
  final t = normalize(heard);
  bool has(List<String> k) => k.any((x) => t.contains(normalize(x)));
  if (allowExpense && has(['খরচ', 'অন্য'])) return 'expense';
  if (optionNames.contains('repaid') && has(['শোধ', 'দেনা'])) return 'repaid';
  if (optionNames.contains('received') && has(['ফেরত', 'পাওনা'])) return 'received';
  if (optionNames.contains('lent') && has(['দিলাম', 'নতুন', 'ধার দি'])) return 'lent';
  if (optionNames.contains('borrowed') && has(['নিলাম', 'নতুন', 'ধার নি'])) return 'borrowed';
  return null;
}
