// Press and hold a chat message to copy it (owner, 31 Oct).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart';

void main() {
  testWidgets('voice view: holding an answer copies it', (t) async {
    String? clip;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData') clip = (c.arguments as Map)['text'] as String?;
      return null;
    });
    final rig = await start(t);
    await t.tap(find.byTooltip('বলুন').first);
    await settle(t);
    await tell(t, rig, 'তুমি কী কী পারো');
    await settle(t);
    final reply = find.byKey(const Key('voice-reply-copy')).last;
    await t.ensureVisible(reply);
    await settle(t);
    // The answer is long: hold near its first line.
    await t.longPressAt(t.getTopLeft(reply) + const Offset(40, 12));
    await settle(t);
    expect(clip, contains('• স্বাস্থ্য'));
    expect(find.text('কপি হয়েছে'), findsOneWidget);
  });
}
