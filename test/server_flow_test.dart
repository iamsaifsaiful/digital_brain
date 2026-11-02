import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riyal_hisab/core/ledger.dart';
import 'package:riyal_hisab/core/models.dart';
import 'package:riyal_hisab/main.dart';
import 'package:riyal_hisab/services/crypto.dart';
import 'package:riyal_hisab/services/device.dart';
import 'package:riyal_hisab/services/lock.dart';
import 'package:riyal_hisab/services/push.dart';
import 'package:riyal_hisab/services/store.dart';
import 'package:riyal_hisab/state/agent_state.dart';
import 'package:riyal_hisab/state/hisab.dart';

import 'fake_server.dart';

Hisab phone(FakeServer server, {FakeDevice? device, FakePush? push, MemoryKeyVault? keys}) {
  final k = keys ?? MemoryKeyVault();
  return Hisab(Services(
    store: DataStore(keys: k, blob: MemoryBlobStore(), photos: MemoryPhotoFiles()),
    lock: LockService(keys: k, biometrics: FakeBiometrics(has: false), iterations: 1000),
    device: device ?? FakeDevice(),
    api: server.api(),
    push: push ?? FakePush(),
  ));
}

Txn draft(String customerId, String agentId, {double sar = 500, String number = '01812345901'}) => Txn(
      id: '',
      no: 0,
      customerId: customerId,
      recipientLabel: 'স্ত্রী',
      number: number,
      method: Method.bkash,
      kind: Kind.send,
      sarAmount: sar,
      rate: 32.5,
      taka: takaFor(sar, 32.5),
      fee: 0,
      agentId: agentId,
      pay: Pay.due,
      sarPaid: 0,
      at: DateTime(2026),
    );

void main() {
  test('owner, agent in the app, second admin with a checklist, offline numbers', () async {
    final server = FakeServer()..addUser('owner', 'সাইফুল', 'saiful', 'owner-pass');
    final owner = phone(server);
    await owner.load();
    final ses = await owner.login('saiful', 'owner-pass');
    expect(ses.isOwner, isTrue);
    expect(owner.can('users'), isTrue);
    await owner.setup(owner: 'সাইফুল', agentName: 'মনোয়ারা স্টোর', agentWhatsapp: '01811111111');
    final agent = owner.d.agents.single;
    await owner.setAgentChannel(agent, 'app');
    await owner.s.api.post('/users', {'role': 'agent', 'name': 'তন্তু ভাই', 'login': '01811111111', 'password': 'agent-pass', 'agent_rid': agent.id});
    final c = await owner.addCustomer(name: 'করিম', phone: '0551234567');
    final t = await owner.addTxn(draft(c.id, agent.id));
    expect(t.no, greaterThan(1000));
    await owner.sync();
    expect(server.one('txn', t.id)!['status'], 'pending');
    expect(server.one('agent', agent.id)!['channel'], 'app');
    expect(server.notes.single['title'], 'নতুন অনুরোধ #${t.no}');

    // The agent, on their own phone.
    final push = FakePush();
    final aPhone = phone(server, push: push);
    await aPhone.load();
    final aSes = await aPhone.login('01811111111', 'agent-pass');
    expect(aSes.isAgent, isTrue);
    expect(aPhone.d.txns, isEmpty, reason: 'an agent phone keeps no account');
    final st = AgentState(aPhone);
    await st.refresh();
    expect(st.waiting.single.no, t.no);
    expect(st.waiting.single.total, 16250);
    expect(st.unread, 1);
    await st.sent(st.waiting.single, tail: '667');
    expect(st.waiting, isEmpty);

    await owner.sync();
    final back = owner.txnById(t.id)!;
    expect(back.status, TxnStatus.sent);
    expect(back.agentReply, '${t.no} 16250-667');
    expect(owner.d.log.last.who, 'তন্তু ভাই');

    // A second admin who may only send.
    await owner.s.api.post('/users', {
      'role': 'admin',
      'name': 'রহিম',
      'login': 'rahim',
      'password': 'rahim-pass',
      'perms': ['send']
    });
    final second = phone(server);
    await second.load();
    await second.login('rahim', 'rahim-pass');
    expect(second.can('send'), isTrue);
    expect(second.can('deposit'), isFalse);
    expect(second.d.customers.single.name, 'করিম');
    expect(second.d.txns.single.status, TxnStatus.sent);
    final t2 = await second.addTxn(draft(c.id, agent.id, sar: 100, number: '01911222338'));
    expect(t2.no, isNot(t.no));
    await second.sync();
    await owner.sync();
    expect(owner.d.txns.length, 2);
    expect(customerDue(owner.d, c.id), 600);
    expect(owner.d.log.where((e) => e.who == 'রহিম'), isNotEmpty);

    // No internet: the numbers kept on the phone still work, then stop.
    server.offline = true;
    final left = second.d.sync.numbers.length;
    for (var i = 0; i < left; i++) {
      await second.addTxn(draft(c.id, agent.id, sar: 10));
    }
    await expectLater(second.addTxn(draft(c.id, agent.id, sar: 10)), throwsA(isA<NoNumbers>()));
    server.offline = false;
    await second.sync();
    await owner.sync();
    expect(owner.d.txns.length, 2 + left);
    expect(owner.d.txns.map((x) => x.no).toSet().length, owner.d.txns.length, reason: 'never the same number twice');

    // A phone that had its own account before: put aside, server's taken.
    final old = phone(server);
    await old.load();
    await old.setup(owner: 'X', agentName: 'Y', agentWhatsapp: '01700000000');
    await old.addCustomer(name: 'পুরনো', phone: '0500000000');
    await old.login('rahim', 'rahim-pass');
    expect(old.d.customers.map((x) => x.name), ['করিম']);

    // Turning a login off signs that phone out at the next sync.
    final rid = server.users.firstWhere((u) => u['login'] == 'rahim')['id'];
    await owner.s.api.post('/users/update', {'id': rid, 'status': 'off'});
    await second.sync();
    expect(second.session, isNull);
    expect(second.d.txns, isEmpty);
  });

  test('two admins: own cash, handover once, shop total once; templates shared', () async {
    final server = FakeServer()..addUser('owner', 'সাইফুল', 'saiful', 'owner-pass');
    final owner = phone(server);
    await owner.load();
    await owner.login('saiful', 'owner-pass');
    await owner.setup(owner: 'সাইফুল', agentName: 'মনোয়ারা স্টোর', agentWhatsapp: '01811111111');
    final agent = owner.d.agents.single;
    final c = await owner.addCustomer(name: 'করিম', phone: '0551234567');
    await owner.addTxn(Txn.fromJson({...draft(c.id, agent.id, sar: 200).toJson(), 'pay': 'cash', 'sarPaid': 200}));
    owner.d.settings.templates['cust_due'] = 'ভাই {নাম}, {বাকি} রিয়াল বাকি।';
    await owner.saveSettings('টেমপ্লেট');
    await owner.s.api.post('/users', {'role': 'admin', 'name': 'রহিম', 'login': 'rahim', 'password': 'rahim-pass', 'perms': ['send', 'deposit']});
    await owner.sync();

    final second = phone(server);
    await second.load();
    await second.login('rahim', 'rahim-pass');
    expect(dueReminder(second.d, second.d.customers.single), startsWith('ভাই করিম,'), reason: 'the owner\'s wording reached this phone');
    final t = await second.addTxn(Txn.fromJson({...draft(c.id, agent.id, sar: 300).toJson(), 'pay': 'cash', 'sarPaid': 300}));
    expect(t.byName, 'রহিম');
    expect(second.myCash, 300);
    await second.sync();
    await owner.sync();
    expect(owner.myCash, 200, reason: 'the owner\'s own hand');
    expect(cashInHand(owner.d), 500, reason: 'the shop: both hands');

    await owner.receiveFrom(second.meId, 'রহিম', 250, '');
    expect(owner.myCash, 450);
    expect(cashInHand(owner.d), 500, reason: 'a handover moves riyal, the shop total stays');
    await owner.sync();
    await second.sync();
    expect(second.myCash, 50);
    expect(cashInHand(second.d, me: owner.meId, owner: true), 450);
  });

  testWidgets('agent app: request, "পাঠিয়েছি" with 3 digits', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final server = FakeServer()..addUser('owner', 'সাইফুল', 'saiful', 'owner-pass');
    late Hisab owner;
    late String txnId;
    await tester.runAsync(() async {
      owner = phone(server);
      await owner.load();
      await owner.login('saiful', 'owner-pass');
      await owner.setup(owner: 'সাইফুল', agentName: 'মনোয়ারা স্টোর', agentWhatsapp: '01811111111');
      final a = owner.d.agents.single;
      await owner.setAgentChannel(a, 'app');
      await owner.s.api.post('/users', {'role': 'agent', 'name': 'তন্তু ভাই', 'login': 'tontu', 'password': 'agent-pass', 'agent_rid': a.id});
      final c = await owner.addCustomer(name: 'করিম', phone: '0551234567');
      txnId = (await owner.addTxn(draft(c.id, a.id))).id;
      await owner.sync();
    });
    final keys = MemoryKeyVault();
    final h = phone(server, keys: keys);
    await tester.runAsync(() async {
      await h.s.lock.setPin('1234');
      await h.load();
      await h.login('tontu', 'agent-pass');
    });
    await tester.pumpWidget(RiyalApp(hisab: h));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(String.fromCharCode(0x09E6 + int.parse(d))).last);
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('৳ ১৬,২৫০'), findsOneWidget);
    expect(find.textContaining('SAR'), findsNothing);
    await tester.tap(find.text('পাঠিয়েছি'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '667');
    await tester.tap(find.text('সাইফুল-কে জানান'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(server.one('txn', txnId)!['status'], 'sent');
    expect(find.textContaining('এখন পাঠানোর মতো কিছু নেই'), findsOneWidget);
    for (final tab in ['সব কাজ', 'টাকা', 'প্রোফাইল']) {
      await tester.tap(find.text(tab).last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }
    expect(find.text('নতুন অনুরোধ #${owner.txnById(txnId)!.no}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an admin without "deposit" sees no deposit button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final server = FakeServer()
      ..addUser('owner', 'সাইফুল', 'saiful', 'owner-pass')
      ..addUser('admin', 'রহিম', 'rahim', 'rahim-pass', perms: ['send']);
    await tester.runAsync(() async {
      final owner = phone(server);
      await owner.load();
      await owner.login('saiful', 'owner-pass');
      await owner.setup(owner: 'সাইফুল', agentName: 'মনোয়ারা স্টোর', agentWhatsapp: '01811111111');
      await owner.sync();
    });
    final keys = MemoryKeyVault();
    final h = phone(server, keys: keys);
    await tester.runAsync(() async {
      await h.s.lock.setPin('1234');
      await h.load();
      await h.login('rahim', 'rahim-pass');
    });
    await tester.pumpWidget(RiyalApp(hisab: h));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(String.fromCharCode(0x09E6 + int.parse(d))).last);
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    expect(find.text('নতুন পাঠানো'), findsOneWidget);
    expect(find.text('রিয়াল জমা'), findsNothing);
    await tester.tap(find.text('রিপোর্ট').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('রিপোর্ট দেখার অনুমতি আপনার নেই'), findsOneWidget);
    await tester.tap(find.text('অন্যান্য').last);
    await tester.pumpAndSettle();
    expect(find.text('লগইন ও অনুমতি'), findsNothing);
    expect(find.text('খরচ / রিয়াল বের'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
