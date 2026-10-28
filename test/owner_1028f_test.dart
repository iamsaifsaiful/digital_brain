import 'dart:convert';

import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/services/trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('সমস্যা খোঁজার লগ to our server (owner, 28 Oct): private conversations stay on the phone, numbers hidden, only new lines next time', () async {
    Trace.enabled = true;
    Trace.clear();
    Trace.conversation = 'c1';
    Trace.log('speech', 'whole speech sent', {'text': 'কাল ০১৭১২৩৪৫৬৭৮ নম্বরে রহিমকে ফোন করতে হবে'});
    Trace.log('understood', 'intent', {'intent': 'reminder_add'});
    Trace.conversation = 'c2';
    Trace.log('speech', 'whole speech sent', {'text': 'আজ রাতে কী খাব'});
    Trace.log('understood', 'intent', {'intent': 'med_query'}); // the whole conversation goes out of the send
    Trace.conversation = 'c3';
    Trace.log('speech', 'whole speech sent', {'text': 'ফেসবুকের পাসওয়ার্ড কী'});
    final t = Trace.forServer();
    expect(t.left, 2);
    expect(t.lines, hasLength(2));
    expect(t.lines.join('\n'), isNot(contains('খাব')));
    expect(t.lines.join('\n'), isNot(contains('পাসওয়ার্ড')));
    expect(t.lines.join('\n'), isNot(contains('০১৭১২৩৪৫৬৭৮')));

    final sent = <http.Request>[];
    final server = AccountServer(MockClient((r) async {
      sent.add(r);
      return http.Response('{"ok":true}', 200);
    }), 'https://example.test');
    expect(await server.sendTrace(t.lines, '2.60.0', ''), isTrue);
    expect(sent.single.url.path, '/wp-json/my-assistant/v1/trace');
    expect((jsonDecode(sent.single.body) as Map)['lines'], hasLength(2));
    // Next time only what came after.
    Trace.sentUpTo = t.upTo;
    Trace.conversation = 'c4';
    Trace.log('chat', 'conversation started');
    expect(Trace.forServer().lines, hasLength(1));
    expect(Trace.forServer(all: true).lines, hasLength(3));
    Trace.clear();
    Trace.enabled = false;
  });
}
