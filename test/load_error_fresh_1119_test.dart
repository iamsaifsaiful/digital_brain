// Owner, 19 Nov: a phone whose data file its key cannot open showed only
// "restore from a backup". Now it can also start fresh, the old file kept aside.
import 'package:digital_brain/app.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart' show MemoryKeyVault;
import 'package:digital_brain/services/data_store.dart' show MemoryDocFiles;
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, enterPin, loadFonts, settle;

void main() {
  testWidgets('unreadable data: start fresh keeps the old file aside and opens the app', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    googleFirst = false;
    final lost = Rig();
    await lost.brain.services.store.save(AppData(notes: [Note(title: 'পুরনো')]));
    final rig = Rig.sharing(lost, keys: MemoryKeyVault());
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    await enterPin(t, '1234');
    await enterPin(t, '1234');
    expect(find.text('তথ্য খোলা যায়নি'), findsOneWidget);
    await t.tap(find.byKey(const Key('load-error-fresh')));
    await settle(t);
    await t.tap(find.byKey(const Key('load-error-fresh-ok')));
    await settle(t);
    expect(rig.brain.loadError, isNull);
    expect(find.text('তথ্য খোলা যায়নি'), findsNothing);
    expect(find.byTooltip('বলুন'), findsOneWidget);
    // Saved with the new key, and the old file is still there, aside.
    await rig.brain.saveTask(Task(title: 'নতুন'));
    final docs = rig.brain.services.store.docFiles as MemoryDocFiles;
    expect(docs.files.keys.any((k) => k.startsWith('unreadable-data-')), isTrue);
  });
}
