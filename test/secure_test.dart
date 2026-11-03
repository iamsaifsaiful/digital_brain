// Screenshots blocked only on secret pages (owner, 31 Oct).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/ui/secure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <Object?>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('my_assistant/secure'), (c) async {
      calls.add(c.arguments);
      return null;
    });
  });

  testWidgets('blocked while a secret page is open, unblocked when the last closes', (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const Text('home')));
    SecureScreens.ready();
    await t.pump();
    expect(calls, [false]);
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SecureView(child: Text('vault'))));
    await t.pumpAndSettle();
    expect(SecureScreens.open, 1);
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SecureView(child: Text('item'))));
    await t.pumpAndSettle();
    expect(SecureScreens.open, 2);
    expect(calls, [false, true]);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(calls, [false, true]);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(SecureScreens.open, 0);
    expect(calls, [false, true, false]);
  });
}
