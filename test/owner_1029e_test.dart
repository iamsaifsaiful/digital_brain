// Owner, 29 Oct (Play Store): Premium in the Play app is bought through
// Google Play and turns on only after our server has checked it with Google.
import 'dart:convert';

import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/services/billing.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show Rig;
import 'pro_test.dart' show tokenGoogle;

void main() {
  late List<Map<String, dynamic>> verified;
  late http.Response Function() verify;
  late Map<String, Object?> me;

  AccountServer server() => AccountServer(
      MockClient((r) async {
        if (r.url.path.endsWith('/login') || r.url.path.endsWith('/me')) {
          return http.Response(jsonEncode({'ok': true, 'session': 'd' * 64, ...me}), 200);
        }
        if (r.url.path.endsWith('/play/verify')) {
          verified.add(jsonDecode(r.body) as Map<String, dynamic>);
          return verify();
        }
        return http.Response('{}', 200);
      }),
      'https://example.test');

  setUp(() {
    verified = [];
    me = {};
    verify = () => http.Response(jsonEncode({'ok': true, 'pro_until': '2027-10-09T00:00:00Z', 'pro_kind': 'play:pro_yearly', 'play_active': true}), 200);
  });

  Future<(Brain, FakeBilling)> signedIn() async {
    final rig = Rig(server: server(), google: tokenGoogle());
    final b = rig.brain..gated = true;
    await b.load();
    expect(await b.signInGoogle(), isNull);
    return (b, rig.services.billing as FakeBilling);
  }

  test('bought: our server checks it with Google, then Premium to the subscription\'s end', () async {
    final (b, play) = await signedIn();
    expect(b.pro, isFalse);
    play.next = const PlayBuy.bought(PlaySub('pro_yearly', 'tok-1'));
    expect(await b.buyPlay(proPlans.first), isNull);
    expect(verified.single, {'product': 'pro_yearly', 'token': 'tok-1'});
    expect((b.pro, b.proKind, b.proUntil), (true, 'play:pro_yearly', DateTime.utc(2027, 10, 9)));
    expect(play.accounts.single, matches(RegExp(r'^[0-9a-f]{64}$')), reason: 'a hash, never the email');
    expect(play.accounts.single, isNot(contains('test')));
  });

  test('closed sheet: nothing; another account\'s purchase: not moved', () async {
    final (b, play) = await signedIn();
    play.next = const PlayBuy.cancelled();
    expect(await b.buyPlay(proPlans.last), '');
    expect(verified, isEmpty);
    play.next = const PlayBuy.bought(PlaySub('pro_monthly', 'tok-2'));
    verify = () => http.Response(jsonEncode({'code': 'taken'}), 409);
    expect(await b.buyPlay(proPlans.last), contains('অন্য একটা অ্যাকাউন্টের'));
    expect(b.pro, isFalse);
  });

  test('server down: Premium for 3 days while waiting; the next start asks again and a plain /me does not take it', () async {
    final (b, play) = await signedIn();
    play.next = const PlayBuy.bought(PlaySub('pro_monthly', 'tok-3'));
    verify = () => http.Response('{}', 503);
    expect(await b.buyPlay(proPlans.last), isNull);
    expect((b.pro, b.proKind), (true, Brain.playPending));
    await b.refreshAccount(force: true);
    expect(b.pro, isTrue, reason: 'the server\'s /me knows nothing yet');
    verify = () => http.Response(jsonEncode({'ok': true, 'pro_until': '2026-11-09T00:00:00Z', 'pro_kind': 'play:pro_monthly', 'play_active': true}), 200);
    expect(await b.restorePlay(), isNull);
    expect((b.proKind, b.proUntil), ('play:pro_monthly', DateTime.utc(2026, 11, 9)));
  });

  test('restore on a new phone; nothing owned says so; refunded at Google ends Premium', () async {
    final (b, play) = await signedIn();
    expect(await b.restorePlay(), contains('পাওয়া যায়নি'));
    play.have = [const PlaySub('pro_yearly', 'tok-4', acknowledged: true)];
    expect(await b.restorePlay(), isNull);
    expect(b.pro, isTrue);
    // Google refunded it: the server ends Premium and says so in /me.
    me = {'pro_until': '2026-10-09T00:00:00Z', 'pro_kind': 'play:pro_yearly'};
    await b.refreshAccount(force: true);
    expect(b.pro, isFalse);
  });

  test('not signed in: Google sign-in comes first', () async {
    final rig = Rig(server: server(), google: tokenGoogle());
    final b = rig.brain..gated = true;
    await b.load();
    (rig.services.billing as FakeBilling).next = const PlayBuy.bought(PlaySub('pro_yearly', 'tok-5'));
    expect(await b.buyPlay(proPlans.first), isNull);
    expect((b.signedIn, b.pro), (true, true));
  });
}
