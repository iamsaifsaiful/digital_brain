import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/nlu/samples.dart';

import 'app_test.dart' show Rig;

void main() {
  test('names are replaced; secrets, phone numbers and codes never leave', () {
    expect(delexicalize('রবিন হায়দারকে ৫০০ টাকা দিলাম, রবিন কাল দেবে', ['রবিন', 'রবিন হায়দার']), '<নাম১>কে ৫০০ টাকা দিলাম, <নাম২> কাল দেবে');
    expect(delexicalize('তুবার জন্মদিন ৩১ অক্টোবর', ['তুবা']), '<নাম১>র জন্মদিন ৩১ অক্টোবর');
    expect(delexicalize('রহিমের নম্বর ০১৭১১২২৩৩৪৪ রাখো', ['রহিম']), isNull);
    expect(delexicalize('ওয়াইফাইয়ের পাসওয়ার্ড কত', []), isNull);
    expect(delexicalize('কোড 482913 এসেছে', []), isNull);
    expect(delexicalize('বেতন ৫০০০০০ টাকা পেলাম', []), 'বেতন ৫০০০০০ টাকা পেলাম');
    expect(delexicalize('মারুফকে ফোন দাও', ['মা']), 'মারুফকে ফোন দাও'); // a name inside another word stays
  });

  test('a sample carries the readings, not the person', () {
    final s = nluSample(textDelex: '<নাম১>কে ৫০০ দিলাম', state: 'idle', local: [('cash_add', 0.62)], finalIntents: ['ledger_add'], appVer: '2.40.0', modelVer: 'bundled-1');
    expect(s['local_conf'], 0.62);
    expect((s['final_json'] as Map)['pieces'], [{'intent': 'ledger_add'}]);
    expect(s.containsKey('user'), isFalse);
  });

  test('samples are on by default; health, medicine and secrets never become one', () {
    final b = Rig().brain;
    expect(b.nluSamplesOn, isTrue);
    expect(b.nluStaysPrivate('প্রেশারের ওষুধ খেলাম দুপুরে', ['health_add']), isTrue);
    expect(b.nluStaysPrivate('ডাক্তারের কাছে যাব কাল', ['task_add']), isTrue);
    expect(b.nluStaysPrivate('জিমেইলের পাসওয়ার্ড কী', ['vault_query']), isTrue);
    expect(b.nluStaysPrivate('আজকের রিমাইন্ডার দাও', ['reminder_query', 'reminder_add']), isFalse);
  });
}
