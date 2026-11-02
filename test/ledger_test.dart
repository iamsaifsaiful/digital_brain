import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:riyal_hisab/core/format.dart';
import 'package:riyal_hisab/core/ledger.dart';
import 'package:riyal_hisab/core/models.dart';
import 'package:riyal_hisab/services/crypto.dart';
import 'package:riyal_hisab/services/device.dart';
import 'package:riyal_hisab/services/lock.dart';
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

    test('agent message has taka only, never riyal', () {
      final t = Txn.fromJson({...draft(fee: 300).toJson(), 'no': 1042});
      final m = agentMessage(t);
      expect(m, contains('#1042'));
      expect(m, contains('01812-345901'));
      expect(m, contains('16,550'));
      expect(m, isNot(contains('রিয়াল')));
      expect(m, isNot(contains('SAR')));
      expect(m, isNot(contains('32')));
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
      expect(t.no, 1001);
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
      await h.payAgent(a, unpaidForAgent(h.d, a.id));
      expect(agentOwed(h.d, a.id), 0);
      expect(unpaidForAgent(h.d, a.id), isEmpty);

      expect(h.d.log.map((e) => e.kind), containsAllInOrder(['sys', 'cust', 'txn', 'edit', 'agent', 'recv', 'agent']));

      // Reload from the encrypted store.
      final h2 = Hisab(h.s);
      await h2.load();
      expect(h2.d.txns.single.sarAmount, 450);
      expect(h2.d.log.length, h.d.log.length);
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
    });
  });
}
