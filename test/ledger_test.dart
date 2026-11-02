import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:riyal_hisab/core/format.dart';
import 'package:riyal_hisab/core/lang.dart';
import 'package:riyal_hisab/core/ledger.dart';
import 'package:riyal_hisab/core/models.dart';
import 'package:riyal_hisab/services/api.dart';
import 'package:riyal_hisab/services/crypto.dart';
import 'package:riyal_hisab/services/device.dart';
import 'package:riyal_hisab/services/lock.dart';
import 'package:riyal_hisab/services/reminders.dart';
import 'package:riyal_hisab/services/store.dart';
import 'package:riyal_hisab/state/hisab.dart';

Txn draft({
  String customerId = 'c1',
  double sarAmount = 500,
  double rate = 32.5,
  double fee = 0,
  Pay pay = Pay.due,
  double sarPaid = 0,
  String number = '01812345901',
  String agentId = 'a1',
}) =>
    Txn(
      id: '',
      no: 0,
      customerId: customerId,
      recipientLabel: 'স্ত্রী',
      number: number,
      method: Method.bkash,
      kind: Kind.send,
      sarAmount: sarAmount,
      rate: rate,
      taka: takaFor(sarAmount, rate),
      fee: fee,
      agentId: agentId,
      pay: pay,
      sarPaid: sarPaid,
      at: DateTime(2026),
    );

Hisab makeHisab(DateTime Function() clock, {FakeDevice? device}) {
  final keys = MemoryKeyVault();
  return Hisab(Services(
    store: DataStore(keys: keys, blob: MemoryBlobStore(), photos: MemoryPhotoFiles()),
    lock: LockService(keys: keys, biometrics: FakeBiometrics(has: false), iterations: 1000),
    device: device ?? FakeDevice(),
    clock: clock,
  ));
}

void main() {
  group('format', () {
    test('Indian grouping with Bangla digits', () {
      expect(bnNum(113750), '১,১৩,৭৫০');
      expect(bnNum(500), '৫০০');
      expect(groupEn(1234567), '12,34,567');
      expect(sar(750), '৭৫০ SAR');
      expect(sar(12.5), '১২.৫ SAR');
      expect(taka(16250), '৳ ১৬,২৫০');
      expect(rateText(32.5), '৩২.৫০');
    });

    test('numbers typed in Bangla or English', () {
      expect(parseNum('৫০০'), 500);
      expect(parseNum('32.50'), 32.5);
      expect(parseNum('১,৬২৫০'), 16250);
      expect(parseNum(''), isNull);
      expect(parseNum('abc'), isNull);
    });

    test('names found in English or Bangla', () {
      expect(soundKey('করিম মিয়া').contains(soundKey('karim')), isTrue);
      expect(soundKey('রহিম উদ্দিন').contains(soundKey('rahim')), isTrue);
      expect(soundKey('মোহাম্মদ সাইফুল').contains(soundKey('mohammad')), isTrue);
      expect(soundKey('মোহাম্মদ সাইফুল').contains(soundKey('muhammed saiful')), isTrue);
      expect(soundKey('জাহাঙ্গীর আলম').contains(soundKey('jahangir')), isTrue);
      expect(soundKey('সুমন হোসেন').contains(soundKey('sumon')), isTrue);
      expect(soundKey('Rahim Uddin').contains(soundKey('রহিম')), isTrue);
      expect(soundKey('করিম মিয়া').contains(soundKey('sumon')), isFalse);
      expect(saMobile('0551234567'), '0551234567');
      expect(saMobile('+966 55 123 4567'), '0551234567');
      expect(saMobile('551234567'), '0551234567');
      expect(saMobile('05512345'), isNull);
      expect(saMaxDigits('05'), 10);
      expect(saMaxDigits('+9665'), 12);
    });

    test('Bangladeshi mobile numbers', () {
      expect(bdMobile('01812-345901'), '01812345901');
      expect(bdMobile('+8801812345901'), '01812345901');
      expect(bdMobile('০১৮১২ ৩৪৫৯০১'), '01812345901');
      expect(bdMobile('0181234590'), isNull);
      expect(bdMobile('01212345901'), isNull);
      expect(waNumber('01812345901'), '8801812345901');
      expect(waNumber('+966 55 123 4567'), '966551234567');
      expect(waNumber('0551234567'), '966551234567');
    });
  });

  group('ledger', () {
    test('customer due in riyal, payments against oldest sends first', () {
      final d = AppData();
      d.txns.add(draft(sarAmount: 500)..at = DateTime(2026, 10, 15));
      d.txns.add(draft(sarAmount: 500, pay: Pay.partial, sarPaid: 200)..at = DateTime(2026, 10, 25));
      d.txns.add(draft(sarAmount: 300, pay: Pay.cash, sarPaid: 300)..at = DateTime(2026, 10, 26));
      expect(customerDue(d, 'c1'), 800);
      d.deposits.add(Deposit(id: 'p', customerId: 'c1', sarAmount: 600, at: DateTime(2026, 10, 27)));
      expect(customerDue(d, 'c1'), 200);
      final open = openSends(d, 'c1');
      expect(open.length, 2);
      expect(open[0].left, 0);
      expect(open[1].left, 200);
      expect(cashInHand(d), 1100);
    });

    test('cancelled sends owe nothing', () {
      final d = AppData();
      d.txns.add(draft()..status = TxnStatus.cancelled);
      expect(customerDue(d, 'c1'), 0);
      expect(agentOwed(d, 'a1'), 0);
    });

    test('agent owed in taka with fee and commission, less payments', () {
      final d = AppData(agents: [Agent(id: 'a1', name: 'এ', whatsapp: '01700000000', commissionPerThousand: 4, created: DateTime(2026))]);
      d.txns.add(draft(sarAmount: 500, rate: 32.5, fee: 300));
      // 16250 + 300 = 16550; commission 4/1000 → 66.2 → 66
      expect(agentOwed(d, 'a1'), 16616);
      d.agentPayments.add(AgentPayment(id: 'x', agentId: 'a1', taka: 20000, at: DateTime(2026)));
      expect(agentOwed(d, 'a1'), -3384);
    });

    test('duplicate warning: same number and taka within minutes', () {
      final d = AppData();
      final now = DateTime(2026, 10, 25, 23, 58);
      d.txns.add(draft()..at = now.subtract(const Duration(minutes: 5)));
      expect(duplicates(d, number: '01812345901', taka: 16250, now: now), hasLength(1));
      expect(duplicates(d, number: '01812345901', taka: 16000, now: now), isEmpty);
      expect(duplicates(d, number: '01812345901', taka: 16250, now: now.add(const Duration(minutes: 30))), isEmpty);
    });

    test('TrxID found in a reply and matched to the waiting send', () {
      expect(trxIdsIn('Done bhai. TrxID BJ7K9X2Q1M'), ['BJ7K9X2Q1M']);
      expect(trxIdsIn('901 bj7k9x2q1m'), ['BJ7K9X2Q1M']);
      expect(trxIdsIn('01812345901 পাঠালাম'), isEmpty);
      final a = draft(number: '01812345901');
      final w1 = Txn.fromJson({...a.toJson(), 'id': 't1', 'no': 1042});
      final w2 = Txn.fromJson({...draft(number: '01911222338').toJson(), 'id': 't2', 'no': 1043});
      expect(matchReply('901 BJ7K9X2Q1M', [w1, w2]).single.id, 't1');
      expect(matchReply('#1043 7AK2L9P3QX', [w1, w2]).single.id, 't2');
      expect(matchReply('BJ7K9X2Q1M', [w1, w2]), isEmpty);
      expect(matchReply('BJ7K9X2Q1M', [w1]).single.id, 't1');
    });

    test('agent reply "10000-667": taka, then 3 digits; never a guess', () {
      final r = parseReply('10000-667');
      expect(r.amount, 10000);
      expect(r.tail, '667');
      expect(parseReply('১০,০০০ - ৬৬৭').amount, 10000);
      final both = parseReply('16250 TrxID BJ7K9X2Q1M');
      expect(both.amount, 16250);
      expect(both.trxIds, ['BJ7K9X2Q1M']);
      expect(parseReply('ok').useful, isFalse);
      expect(parseReply('01812345901').useful, isFalse);

      Txn w(String id, int no, double sarAmt, String number) => Txn.fromJson({...draft(sarAmount: sarAmt, number: number).toJson(), 'id': id, 'no': no});
      final a = w('a', 1, 500, '01812345901'); // 16,250
      final b = w('b', 2, 400, '01911222338'); // 13,000
      final c = w('c', 3, 500, '01711000667'); // 16,250 again
      expect(matchReply('13000-555', [a, b]).single.id, 'b');
      // The send's number first: that one, whatever else matches.
      expect(parseReply('1002 13000-555', nos: [1001, 1002]).no, 1002);
      final ab = [w('x', 1042, 500, '01812345901'), w('y', 1043, 500, '01711000667')];
      expect(matchReply('1043 16250-901', ab).single.id, 'y');
      expect(matchReply('#1042 16250-667', ab).single.id, 'x');
      expect(matchReply('1043 BJ7K9X2Q1M', ab).single.id, 'y');
      expect(parseReply('1043 16250-901', nos: [1042, 1043]).amount, 16250);
      // A number that is not a waiting send is not taken as one.
      expect(matchReply('1099 16250-901', ab).map((x) => x.id), ['x', 'y']);
      // Same taka twice: the 3 digits are the agent's own number, so ask.
      expect(matchReply('16250-667', [a, b, c]).map((x) => x.id), ['a', 'c']);
      // Taka that no send has: nothing, even with one send waiting.
      expect(matchReply('9999-667', [a]), isEmpty);
      expect(matchReply('16250 BJ7K9X2Q1M', [a, b]).single.id, 'a');
    });

    test('loss takes riyal off the due but adds nothing to cash', () {
      final d = AppData();
      d.txns.add(draft(sarAmount: 500));
      final cash = cashInHand(d);
      d.losses.add(Loss(id: 'l', customerId: 'c1', sarAmount: 300, at: DateTime(2026)));
      expect(customerDue(d, 'c1'), 200);
      expect(lossOf(d), 300);
      expect(cashInHand(d), cash);
      expect(openSends(d, 'c1').single.left, 200);
    });

    test('recharge and MB messages: number, operator, pack, taka; no riyal', () {
      final t = Txn.fromJson({...draft(sarAmount: 20, rate: 32.5, number: '01812345901').toJson(), 'no': 1050, 'kind': 'mb', 'operator': 'রবি', 'pack': '৩০ জিবি ৩০ দিন'});
      final m = agentMessage(t);
      expect(m, contains('এমবি প্যাক'));
      expect(m, contains('রবি'));
      expect(m, contains('৩০ জিবি'));
      expect(m, contains('650'));
      expect(m, isNot(contains('SAR')));
      expect(m, isNot(contains('রিয়াল')));
      expect(operatorOf('01812345901'), 'রবি');
      expect(operatorOf('01712345678'), 'গ্রামীণফোন');
    });

    test('message templates: own wording, empty lines dropped, default kept', () {
      expect(fillTemplate('a {x}\nb: {y}\nc', {'x': '1', 'y': ''}), 'a 1\nc');
      expect(fillTemplate('{z} stays', {'x': '1'}), '{z} stays');
      final d = AppData();
      final t = Txn.fromJson({...draft().toJson(), 'no': 26110001});
      final before = agentMessage(t, d);
      expect(before, agentMessage(t));
      d.settings.templates['agent_send'] = 'ভাই, {নম্বর} এ {টাকা} টাকা {মাধ্যম} করুন। নং {নং}\nনোট: {খরচ}';
      final m = agentMessage(t, d);
      expect(m, 'ভাই, 01812-345901 এ 16,250 টাকা বিকাশ করুন। নং 26110001');
      final back = Settings.fromJson(d.settings.toJson());
      expect(back.templates['agent_send'], d.settings.templates['agent_send']);
      final other = Settings()..applyShared(d.settings.shared());
      expect(other.templates, d.settings.templates);
      expect(unknownFields(templateOf('cust_due'), '{নাম} {ভুল}'), ['ভুল']);
    });

    test('English switch: phrases, words in longer text, digits; names kept', () {
      appEnglish = true;
      addTearDown(() => appEnglish = false);
      expect(tr('সব লেনদেন'), 'All transactions');
      expect(tr('আজ ১০টা লেনদেন · ৪,০০০ SAR'), 'Today 10 Transactions · 4,000 SAR');
      expect(tr('করিম মিয়া'), 'করিম মিয়া');
      expect(tr('${bn('7')} দিন পর'), '7 days later');
      appEnglish = false;
      expect(tr('সব লেনদেন'), 'সব লেনদেন');
    });

    test('the server address is scrambled the same way as tool/hide_server.py', () {
      expect(hideServer('https://shop.example.com'), '1a3c5749051b635e442817201c3b153b1f384f5c5842231c');
    });

    test('agent message has taka only, never riyal', () {
      final t = Txn.fromJson({...draft(fee: 300).toJson(), 'no': 1042});
      final m = agentMessage(t);
      expect(m, contains('#1042'));
      expect(m, contains('01812-345901'));
      expect(m, contains('16,550'));
      expect(m, isNot(contains('রিয়াল')));
      expect(m, isNot(contains('SAR')));
      expect(m, isNot(contains('32')));
      expect(m, contains('আগে লেনদেন নং'));
      expect(m, contains('1042 16550-XXX'));
      expect(m, contains('যে নম্বর থেকে পাঠালেন'));
    });
  });

  group('state', () {
    test('send, deposit, agent payment, edit and log; saved encrypted', () async {
      var clock = DateTime(2026, 10, 25, 23, 58);
      final h = makeHisab(() => clock);
      await h.load();
      expect(h.needsSetup, isTrue);
      await h.setup(owner: 'সাইফুল', agentName: 'মনোয়ারা স্টোর', agentWhatsapp: '01800000000', commission: 0);
      expect(h.needsSetup, isFalse);
      final c = await h.addCustomer(name: 'করিম মিয়া', phone: '+966 55 123 4567');
      final a = h.d.agents.single;
      final t = await h.addTxn(draft(customerId: c.id, agentId: a.id));
      expect(t.no, 26100001);
      expect(c.recipients.single.number, '01812345901');
      expect(customerDue(h.d, c.id), 500);
      expect(agentOwed(h.d, a.id), 16250);

      final changed = t.copy()
        ..sarAmount = 450
        ..taka = takaFor(450, 32.5);
      final diffs = await h.editTxn(t, changed);
      expect(diffs, hasLength(2));
      expect(customerDue(h.d, c.id), 450);

      clock = clock.add(const Duration(minutes: 8));
      await h.setTrxId(h.txnById(t.id)!, 'bj7k9x2q1m');
      expect(h.txnById(t.id)!.status, TxnStatus.sent);
      expect(h.waiting, isEmpty);

      await h.addDeposit(c, 200);
      expect(customerDue(h.d, c.id), 250);
      await h.payAgent(a, unpaidForAgent(h.d, a.id), sarOut: 500);
      expect(agentOwed(h.d, a.id), 0);
      expect(unpaidForAgent(h.d, a.id), isEmpty);

      expect(h.d.log.map((e) => e.kind), containsAllInOrder(['sys', 'cust', 'txn', 'edit', 'agent', 'recv', 'agent']));

      // Reload from the encrypted store.
      final h2 = Hisab(h.s);
      await h2.load();
      expect(h2.d.txns.single.sarAmount, 450);
      expect(h2.d.log.length, h.d.log.length);
    });

    test('receipt: no "বকেয়া নেই" line, পিন from the agent or as typed', () {
      final d = AppData(customers: [Customer(id: 'c1', name: 'করিম', phone: '0551234567', created: DateTime(2026))]);
      final t = Txn.fromJson({...draft(pay: Pay.cash, sarPaid: 500).toJson(), 'no': 26110001, 'status': 'sent', 'replyTail': '667'});
      d.txns.add(t);
      final m = customerReceipt(d, t);
      expect(m, isNot(contains('বকেয়া')));
      expect(m, contains('পিন: 667'));
      expect(customerReceipt(d, t, pin: '1667'), contains('পিন: 1667'));
      expect(customerReceipt(d, t, pin: ''), isNot(contains('পিন')));
      d.txns.add(Txn.fromJson({...draft(sarAmount: 100).toJson(), 'id': 't2', 'no': 26110002}));
      expect(customerReceipt(d, t), contains('আপনার মোট বকেয়া: 100 রিয়াল'));
    });

    test('a sent send is never edited; অতিরিক্ত হিসাব counts only once added', () async {
      final h = makeHisab(() => DateTime(2026, 11, 2, 10));
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      final c = await h.addCustomer(name: 'করিম', phone: '0551234567');
      final t = await h.addTxn(Txn.fromJson({...draft(customerId: c.id, agentId: h.d.agents.single.id).toJson()}));
      await h.markSent(t, trxId: 'BK7X2Q9');
      await expectLater(h.editTxn(t, t.copy()..sarAmount = 600), throwsStateError);
      final due = customerDue(h.d, c.id), cash = h.myCash, owed = agentOwed(h.d, t.agentId);
      final x = await h.addAdjust(t, sarDue: 50, sarCash: -20, takaAgent: 650, note: 'রিয়াল কম লিখেছিলাম');
      expect((customerDue(h.d, c.id), h.myCash, agentOwed(h.d, t.agentId)), (due, cash, owed));
      await h.applyAdjust(x);
      expect((customerDue(h.d, c.id), h.myCash, agentOwed(h.d, t.agentId)), (due + 50, cash - 20, owed + 650));
      expect(adjustText(x), 'গ্রাহকের বকেয়া +৫০ SAR · হাতে −২০ SAR · এজেন্টের পাওনা +৳ ৬৫০');
    });

    test('a change of amount before sending must be told to a WhatsApp agent', () async {
      final h = makeHisab(() => DateTime(2026, 11, 2, 10));
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      final c = await h.addCustomer(name: 'করিম', phone: '0551234567');
      final t = await h.addTxn(Txn.fromJson({...draft(customerId: c.id, agentId: h.d.agents.single.id).toJson()}));
      await h.editTxn(t, t.copy()..recipientLabel = 'মা');
      expect(h.txnById(t.id)!.changeNotice, '', reason: 'nothing the agent sends changed');
      final t1 = h.txnById(t.id)!;
      await h.editTxn(t1, t1.copy()..taka = 17000);
      expect(h.txnById(t.id)!.changeNotice, 'pending');
      await h.changeNoticeSent(h.txnById(t.id)!);
      expect(h.txnById(t.id)!.changeNotice, '');
    });

    test('a send without a profile: cash only, named on the send', () async {
      final h = makeHisab(() => DateTime(2026, 11, 2, 10));
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      final t = await h.addTxn(Txn.fromJson({...draft(customerId: '', agentId: h.d.agents.single.id, pay: Pay.cash, sarPaid: 500).toJson(), 'walkIn': 'রাস্তার ভাই', 'walkInPhone': '0559999999'}));
      expect(customerNameOf(h.d, t), 'রাস্তার ভাই');
      expect(h.d.customers, isEmpty);
      expect(h.myCash, 500);
      expect(customerReceipt(h.d, t), contains('রাস্তার ভাই'));
      expect(customerNameOf(h.d, Txn.fromJson({...t.toJson(), 'walkIn': ''})), 'প্রোফাইল ছাড়া');
    });

    test('agent payment: only the riyal can be corrected, and the hand follows', () async {
      final h = makeHisab(() => DateTime(2026, 11, 2, 10));
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      final c = await h.addCustomer(name: 'করিম', phone: '0551234567');
      await h.addDeposit(c, 500);
      final p = await h.advanceAgent(h.d.agents.single, 10000, sarOut: 310);
      expect(h.myCash, 190);
      await h.editPaymentSar(p, 300, why: 'ভুল লিখেছিলাম');
      expect(h.myCash, 200);
      expect(p.taka, 10000);
      expect(h.d.log.last.title, 'এজেন্টকে পরিশোধের রিয়াল বদল');
      expect(h.d.log.last.detail, contains('৩১০ SAR → ৩০০ SAR'));
      expect(h.d.log.last.detail, contains('ভুল লিখেছিলাম'));
    });

    test('backup restores data and photos with the password only', () async {
      final h = makeHisab(() => DateTime(2026, 11, 1));
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      await h.addCustomer(name: 'করিম', phone: '0551234567', photo: Uint8List.fromList([1, 2, 3]));
      final bytes = await h.exportBackup('pass1234');
      final other = makeHisab(() => DateTime(2026, 11, 2));
      await other.load();
      await expectLater(other.restoreBackup(bytes, 'wrong'), throwsA(isA<WrongKey>()));
      await other.restoreBackup(bytes, 'pass1234');
      expect(other.d.customers.single.name, 'করিম');
      expect(await other.photo(other.d.customers.single.photo!), [1, 2, 3]);
    });

    test('promise reminder, loss, wrong-number mark, no cancel after sent', () async {
      final rem = FakeReminders();
      final keys = MemoryKeyVault();
      final h = Hisab(Services(
        store: DataStore(keys: keys, blob: MemoryBlobStore(), photos: MemoryPhotoFiles()),
        lock: LockService(keys: keys, biometrics: FakeBiometrics(has: false), iterations: 1000),
        device: FakeDevice(),
        reminders: rem,
        clock: () => DateTime(2026, 11, 1, 10),
      ));
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      final c = await h.addCustomer(name: 'করিম', phone: '0551234567');
      final t = await h.addTxn(draft(customerId: c.id, agentId: h.d.agents.single.id));
      await h.setPromise(c, DateTime(2026, 11, 5, 9), 'বেতন পেলে');
      expect(rem.scheduled[c.id], DateTime(2026, 11, 5, 9));
      expect(h.promisesDue, isEmpty);

      await h.markSent(t, reply: '16250-667', tail: '667');
      expect(t.status, TxnStatus.sent);
      expect(t.agentReply, '16250-667');
      expect(() => h.cancelTxn(t, 'x'), throwsStateError);
      await h.markFault(t, Fault.agent, 'শেষ সংখ্যা ভুল');
      expect(h.d.txns.single.fault, Fault.agent);

      await h.addLoss(c, 500, 'দেশে চলে গেছেন');
      expect(customerDue(h.d, c.id), 0);
      // Nothing owed any more: the reminder is taken off.
      expect(rem.scheduled, isEmpty);
      expect(h.d.log.map((e) => e.title), containsAll(['বকেয়া ফেরতের তারিখ', 'এজেন্ট পাঠিয়েছেন · #২৬১১০০০১', 'ভুল নম্বরে গেছে · #২৬১১০০০১', 'লস ধরা হলো (আদায় হবে না)']));
    });

    test('a backup made by the server (Drive / download) opens in the app', () async {
      // Made by server/test/e2e.php (RH_BACKUP_OUT) with the password below.
      final bytes = File('test/fixtures/server_backup.rhb').readAsBytesSync();
      final h = makeHisab(() => DateTime(2026, 11, 2));
      await h.load();
      await expectLater(h.restoreBackup(bytes, 'nope'), throwsA(isA<WrongKey>()));
      await h.restoreBackup(bytes, 'backup-pass-1');
      expect(h.d.customers.single.name, 'করিম মিয়া');
      expect(h.d.txns, hasLength(3));
      expect(h.d.agents.single.usesApp, isTrue);
      expect(customerDue(h.d, 'c1'), 200);
      expect(h.d.txns.firstWhere((t) => t.id == 't1').agentReply, endsWith('16450-667'));
      expect(await h.photo('rc1'), isNotNull);
    });

    test('clipboard TrxID is offered for the waiting send', () async {
      final dev = FakeDevice();
      final h = makeHisab(() => DateTime(2026, 11, 1), device: dev);
      await h.load();
      await h.setup(owner: 'সাইফুল', agentName: 'এ', agentWhatsapp: '01800000000');
      final c = await h.addCustomer(name: 'করিম', phone: '0551234567');
      await h.addTxn(draft(customerId: c.id, agentId: h.d.agents.single.id));
      dev.clip = 'Done. 901 TrxID BJ7K9X2Q1M';
      final hit = await h.clipboardTrx();
      expect(hit!.trxId, 'BJ7K9X2Q1M');
      expect(hit.matches, hasLength(1));
      dev.clip = '16250-667';
      final hit2 = await h.clipboardTrx();
      expect(hit2!.reply.amount, 16250);
      expect(hit2.matches, hasLength(1));
      dev.clip = '5000-667';
      expect((await h.clipboardTrx())!.matches, isEmpty);
    });
  });
}
