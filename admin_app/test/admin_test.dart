import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_assistant_admin/api.dart';
import 'package:my_assistant_admin/main.dart';

final _now = DateTime.now().toUtc();
String _ago(Duration d) => _now.subtract(d).toIso8601String();

/// A pretend server with what the admin app shows.
class FakeServer {
  final calls = <http.Request>[];
  final payments = <Map<String, Object?>>[
    {'id': 1, 'created': _ago(const Duration(minutes: 30)), 'email': 'rakib.hasan92@gmail.com', 'name': 'রাকিব হাসান', 'phone': '', 'plan': 'বার্ষিক', 'amount': 999, 'method': 'বিকাশ', 'sender': '01712345678', 'trx': 'BJK4Q9X2PL', 'note': '', 'status': 'pending', 'reason': '', 'reviewed_by': '', 'reviewed': null},
    {'id': 2, 'created': _ago(const Duration(hours: 2)), 'email': 'ayesha.s@gmail.com', 'name': 'Ayesha Siddika', 'phone': '', 'plan': 'মাসিক', 'amount': 99, 'method': 'নগদ', 'sender': '01987654321', 'trx': '7NG2KD81QZ', 'note': 'তাড়াতাড়ি চালু করবেন', 'status': 'pending', 'reason': '', 'reviewed_by': '', 'reviewed': null},
  ];

  final feedback = <Map<String, Object?>>[
    {'id': 7, 'created': _ago(const Duration(minutes: 12)), 'updated': _ago(const Duration(minutes: 12)), 'email': 'rakib.hasan92@gmail.com', 'name': 'রাকিব হাসান', 'kind': 'problem', 'kind_label': 'সমস্যা', 'text': 'রাত ১০টার রিমাইন্ডার বাজেনি', 'version': '2.15.0', 'status': 'new', 'count': 1},
  ];
  final messages = <Map<String, Object?>>[
    {'id': 70, 'from': 'member', 'admin': '', 'text': 'রাত ১০টার রিমাইন্ডার বাজেনি', 'created': _ago(const Duration(minutes: 12)), 'file': {'name': 'screen.png', 'mime': 'image/png', 'size': 70}},
  ];
  final replies = <Map<String, dynamic>>[];

  late final client = MockClient((r) async {
    calls.add(r);
    final p = r.url.path.replaceFirst('/wp-json/my-assistant/v1', '');
    Object body = {};
    if (p == '/admin/summary') {
      body = {'members': 1284, 'pro': 96, 'trial': 41, 'new_week': 63, 'active_week': 712, 'pending_payments': payments.where((x) => x['status'] == 'pending').length, 'income_month': 18981, 'ai_today': 318, 'feedback_new': feedback.where((x) => x['status'] == 'new').length};
    } else if (p == '/admin/payments' && r.method == 'GET') {
      body = {'payments': payments.where((x) => x['status'] == r.url.queryParameters['status']).toList()};
    } else if (p.startsWith('/admin/payments/')) {
      final id = int.parse(p.split('/').last);
      final pay = payments.firstWhere((x) => x['id'] == id);
      pay['status'] = jsonDecode(r.body)['decision'] == 'approve' ? 'approved' : 'rejected';
      body = {'ok': true, 'message': 'অনুমোদন দেওয়া হলো, ${pay['email']}-এ প্রো চালু হলো।'};
    } else if (p == '/admin/feedback') {
      body = {'feedback': feedback.where((x) => r.url.queryParameters['status'] == 'all' || (r.url.queryParameters['status'] == 'done') == (x['status'] == 'done')).toList()};
    } else if (p == '/admin/feedback/file/70') {
      body = {'name': 'screen.png', 'mime': 'image/png', 'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='};
    } else if (p == '/admin/feedback/7/reply') {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      replies.add(j);
      messages.add({'id': 71, 'from': 'admin', 'admin': 'Boss', 'text': j['text'], 'created': _ago(Duration.zero), 'file': j['file'] == null ? null : {'name': j['file']['name'], 'mime': 'image/png', 'size': 1}});
      body = {'ok': true};
    } else if (p == '/admin/feedback/7' && r.method == 'GET') {
      body = {'feedback': feedback.first, 'messages': messages};
    } else if (p.startsWith('/admin/feedback/')) {
      feedback.firstWhere((x) => x['id'] == int.parse(p.split('/').last))['status'] = jsonDecode(r.body)['status'];
      body = {'ok': true};
    } else if (p == '/admin/members') {
      body = {'members': [
        {'id': 1, 'name': 'সাইফুল ইসলাম', 'email': 'saiful.islam@gmail.com', 'picture': '', 'status': 'pro', 'pro_until': '2027-08-12T00:00:00Z', 'joined': _ago(const Duration(days: 20)), 'last_seen': _ago(const Duration(hours: 1)), 'version': '2.14.0 play', 'note': ''},
        {'id': 2, 'name': 'Nusrat Jahan', 'email': 'nusrat.j@gmail.com', 'picture': '', 'status': 'trial', 'pro_until': _now.add(const Duration(days: 5)).toIso8601String(), 'joined': _ago(const Duration(days: 2)), 'last_seen': _ago(const Duration(hours: 3)), 'version': '2.14.0 play', 'note': ''},
        {'id': 3, 'name': '', 'email': 'sumon.dhaka@gmail.com', 'picture': '', 'status': 'free', 'pro_until': null, 'joined': _ago(const Duration(days: 30)), 'last_seen': _ago(const Duration(days: 1)), 'version': '2.14.0 direct', 'note': ''},
      ]};
    } else if (p == '/admin/notices') {
      body = {'notices': [
        {'id': '1', 'title': 'আজকের কাজের লিস্ট করেছেন?', 'body': 'চাপুন আর বলুন — কাল কী কী করবেন, লিখে রাখবো।', 'kind': 'daily', 'at_time': '21:00', 'active': '1'},
        {'id': '2', 'title': 'শুক্রবারের পরিকল্পনা', 'body': 'ছুটির দিনে কী কী করবেন?', 'kind': 'weekly', 'at_time': '20:30', 'active': '0'},
      ]};
    } else if (p == '/admin/login') {
      final j = jsonDecode(r.body);
      if (j['email'] != 'boss@gmail.com' || j['password'] != 'long-password-123') return http.Response('{"code":"login"}', 401);
      body = {'session': 'c' * 64, 'name': 'Boss'};
    }
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
}

/// No fingerprint hardware and no Firebase in tests.
class FakeDevice extends Device {
  bool hasFingerprint = false;
  @override
  Future<bool> canFingerprint() async => hasFingerprint;
  String? answer;
  @override
  Future<String?> verify(String reason) async => answer;
  @override
  Future<String?> pushToken() async => null;
}

Future<void> loadFonts() async {
  final hind = FontLoader('Hind');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    hind.addFont(rootBundle.load('assets/fonts/HindSiliguri-$w.ttf'));
  }
  await hind.load();
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<FakeServer> open(WidgetTester t, {bool signedIn = true}) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3.0;
  addTearDown(t.view.reset);
  await loadFonts();
  final server = FakeServer();
  final store = MemorySession()..value = signedIn ? 'c' * 64 : null;
  await t.pumpWidget(AdminApp(api: Api(client: server.client, store: store, base: 'https://getmyassistant.app'), device: FakeDevice()));
  await settle(t);
  return server;
}

final shots = Platform.environment['SHOTS'] == '1';
Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

void main() {
  testWidgets('summary, then approve a payment; only the session goes to the server', (t) async {
    final server = await open(t);
    expect(find.text('১,২৮৪'), findsOneWidget);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsOneWidget);
    await shot(t, 'dashboard');
    await t.tap(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'));
    await settle(t);
    expect(find.text('BJK4Q9X2PL'), findsOneWidget);
    await shot(t, 'payments');
    await t.tap(find.widgetWithText(FilledButton, 'অনুমোদন').first);
    await settle(t);
    expect(find.text('পেমেন্ট মিলেছে?'), findsOneWidget);
    await shot(t, 'approve');
    await t.tap(find.text('মিলেছে — প্রো দিন'));
    await settle(t);
    expect(server.payments.first['status'], 'approved');
    final decided = server.calls.firstWhere((r) => r.url.path.endsWith('/admin/payments/1'));
    expect(decided.headers['authorization'], 'Bearer ${'c' * 64}');
    expect(find.text('BJK4Q9X2PL'), findsNothing);
  });

  testWidgets('members and notifications', (t) async {
    await open(t);
    await t.tap(find.text('সদস্য').last);
    await settle(t);
    expect(find.text('সাইফুল ইসলাম'), findsOneWidget);
    await shot(t, 'members');
    await t.tap(find.text('সাইফুল ইসলাম'));
    await settle(t);
    expect(find.text('+১ বছর'), findsOneWidget);
    await t.tapAt(const Offset(20, 40));
    await settle(t);
    await t.tap(find.text('নোটিফিকেশন').last);
    await settle(t);
    expect(find.text('আজকের কাজের লিস্ট করেছেন?'), findsOneWidget);
    await shot(t, 'notices');
  });

  testWidgets('feedback: open a conversation, see the screenshot, answer with text', (t) async {
    final server = await open(t);
    await t.tap(find.text('মতামত').last);
    await settle(t);
    expect(find.text('রাত ১০টার রিমাইন্ডার বাজেনি'), findsOneWidget);
    await shot(t, 'feedback');
    await t.tap(find.text('রাত ১০টার রিমাইন্ডার বাজেনি'));
    await settle(t);
    expect(find.text('রাকিব হাসান'), findsOneWidget);
    expect(server.calls.any((r) => r.url.path.endsWith('/admin/feedback/file/70')), isTrue, reason: 'the screenshot is fetched');
    await t.enterText(find.byKey(const Key('admin-reply')), 'ফোনের ব্যাটারি সেটিং দেখুন');
    await t.tap(find.byKey(const Key('admin-send')));
    await settle(t);
    expect(server.replies.single['text'], 'ফোনের ব্যাটারি সেটিং দেখুন');
    expect(find.text('ফোনের ব্যাটারি সেটিং দেখুন'), findsOneWidget);
    await shot(t, 'thread');
  });

  testWidgets('signed out: email and password, then in', (t) async {
    final server = await open(t, signedIn: false);
    expect(find.text('লগইন'), findsOneWidget);
    await shot(t, 'signin');
    await t.enterText(find.byKey(const Key('email')), 'boss@gmail.com');
    await t.enterText(find.byKey(const Key('password')), 'wrong-one');
    await t.tap(find.byKey(const Key('sign-in')));
    await settle(t);
    expect(find.textContaining('মেলেনি'), findsOneWidget);
    await t.enterText(find.byKey(const Key('password')), 'long-password-123');
    await t.tap(find.byKey(const Key('sign-in')));
    await settle(t);
    await settle(t);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsOneWidget);
    expect(server.calls.where((r) => r.url.path.endsWith('/admin/login')).length, 2);
  });

  testWidgets('fingerprint lock when it is on', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    final server = FakeServer();
    final store = MemorySession()..value = 'c' * 64;
    store.flags['fingerprint'] = true;
    final device = FakeDevice()..answer = 'ফোনে কোনো আঙুলের ছাপ রাখা নেই';
    await t.pumpWidget(AdminApp(api: Api(client: server.client, store: store, base: 'https://x'), device: device));
    await settle(t);
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    // The phone said why it could not: shown under the button, still locked.
    expect(find.byKey(const Key('unlock-problem')), findsOneWidget);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsNothing);
    device.answer = null;
    await t.tap(find.byKey(const Key('unlock')));
    await settle(t);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsOneWidget);
  });

  test('only the session is kept; logout forgets it and the fingerprint', () async {
    final server = FakeServer();
    final store = MemorySession();
    final api = Api(client: server.client, store: store, base: 'https://x');
    await expectLater(api.login('boss@gmail.com', 'nope'), throwsA(isA<ApiError>()));
    expect(store.value, isNull);
    expect(await api.login('boss@gmail.com', 'long-password-123'), 'Boss');
    expect(store.value, 'c' * 64);
    await api.setFingerprint(true);
    expect(await api.fingerprintOn(), isTrue);
    await api.logout();
    expect(store.value, isNull);
    expect(await api.fingerprintOn(), isFalse);
  });
}
