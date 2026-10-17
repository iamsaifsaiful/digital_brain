// The words of one listening turn, joined from several recogniser sessions.
import 'package:digital_brain/services/speech_join.dart';
import 'package:flutter_test/flutter_test.dart';

String same(String s) => s;

void main() {
  test('three sessions: every part kept, in order', () {
    final j = SpeechJoin();
    var s = j.newSession();
    j.result(s, 'এ মাসে', isFinal: false, clean: same);
    j.result(s, 'এ মাসে কি আমার', isFinal: false, clean: same);
    expect(j.text, 'এ মাসে কি আমার', reason: 'a partial only replaces the current piece');
    j.result(s, 'এ মাসে কি আমার', isFinal: true, clean: same);
    s = j.newSession(); // the recogniser stopped at a pause and was restarted
    expect(j.text, 'এ মাসে কি আমার', reason: 'a restart clears nothing');
    j.result(s, 'কোন লেনদেন', isFinal: false, clean: same);
    j.result(s, 'কোন লেনদেন আছে', isFinal: true, clean: same);
    s = j.newSession();
    j.result(s, 'অন্যান্য লেনদেন', isFinal: true, clean: same);
    expect(j.text, 'এ মাসে কি আমার কোন লেনদেন আছে অন্যান্য লেনদেন');
  });

  test('a final sent twice is added once; the same words said again later are kept', () {
    final j = SpeechJoin();
    final a = j.newSession();
    j.result(a, 'ঠিক আছে', isFinal: true, clean: same);
    j.result(a, 'ঠিক আছে', isFinal: true, clean: same);
    expect(j.text, 'ঠিক আছে');
    final b = j.newSession();
    j.result(b, 'ঠিক আছে', isFinal: true, clean: same);
    expect(j.text, 'ঠিক আছে ঠিক আছে', reason: 'said twice on purpose, in two sessions');
  });

  test('a late callback from an older session changes nothing', () {
    final j = SpeechJoin();
    final a = j.newSession();
    j.result(a, 'রহিমকে পাঁচশ', isFinal: true, clean: same);
    final b = j.newSession();
    j.result(b, 'টাকা', isFinal: false, clean: same);
    expect(j.result(a, 'রহিমকে পাঁচশ টাকা ধার', isFinal: false, clean: same), isFalse);
    expect(j.text, 'রহিমকে পাঁচশ টাকা');
  });

  test('a session that ended before its final: its words kept, then corrected by the late final — never doubled', () {
    final j = SpeechJoin();
    final a = j.newSession();
    j.result(a, 'কাল সকাল দশটায়', isFinal: false, clean: same);
    j.sessionEnded(same);
    expect(j.text, 'কাল সকাল দশটায়');
    j.newSession();
    j.result(a, 'কাল সকাল দশটায় মিটিং', isFinal: true, clean: same);
    expect(j.text, 'কাল সকাল দশটায় মিটিং');
  });

  test('a phone that sends a growing final again and again in one session: no doubling (recording 17 Oct)', () {
    final j = SpeechJoin();
    final a = j.newSession();
    for (final w in ['তুমি', 'তুমি ২০২৭', 'তুমি ২০২৭ সালের', 'তুমি ২০২৭ সালের জানুয়ারি মাসের প্রথম তারিখে']) {
      j.result(a, w, isFinal: false, clean: same);
      j.result(a, w, isFinal: true, clean: same);
    }
    expect(j.text, 'তুমি ২০২৭ সালের জানুয়ারি মাসের প্রথম তারিখে');
    final b = j.newSession();
    j.result(b, 'চলে যেতে হবে', isFinal: true, clean: same);
    j.result(b, 'চলে যেতে হবে এরকম একটা কাজের তালিকা লেখ', isFinal: true, clean: same);
    expect(j.text, 'তুমি ২০২৭ সালের জানুয়ারি মাসের প্রথম তারিখে চলে যেতে হবে এরকম একটা কাজের তালিকা লেখ');
  });
}
