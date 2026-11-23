// Owner, 24 Nov: "ব্যাকআপ রিস্টোর করলে ... সকল প্রকার সেটিংস, প্রোফাইলের তথ্য,
// সবই আসা উচিত" — settings and profile kept on the phone travel with backups.
import 'dart:convert';
import 'dart:typed_data';

import 'package:digital_brain/logic/weather.dart' show tempF;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/lock.dart';
import 'package:digital_brain/services/data_store.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig;

void main() {
  test('a backup brings back theme, language, profile and every setting; the PIN and phone-only things stay', () async {
    final old = Rig();
    await old.brain.load();
    final b = old.brain..data = AppData(notes: [Note(title: 'পুরনো নোট')], emergency: const EmergencyCard(blood: 'B+'));
    await b.setLook(Look.dark);
    await b.setAccent('purple');
    await b.setEnglish(true);
    await b.setLetterSize(1.15);
    await b.setUserName('সাইফ');
    await b.setUserPhone('+8801700000000');
    await b.setDistrict('চট্টগ্রাম');
    await b.setPhoto(Uint8List.fromList([1, 2, 3]));
    await b.setQuickQuestions(['আজ কী কাজ?']);
    await b.setPref('morning_at', 6 * 60);
    await b.setPref('calendars', 'bn,hijri');
    await b.setPref('weather_places', '["সিলেট"]');
    await b.setPref('temp_unit', 'f');
    await b.setPref('religion', 'islam');
    await b.setPref('money_hidden', 'true');
    await b.setPref('note_cats', '["ব্যবসা"]');
    await b.setPref('ask_sleep', 'true');
    await b.setPref('last_backup', '2026-11-20T10:00:00.000');
    final vault = b.services.lock.keys;
    await vault.write('chat_history', '[]');
    await vault.write('heir_scope', 'docs,notes');
    await vault.write('fam_seed', 'c2VlZA==');
    await b.services.lock.setAutoLockSeconds(120);
    await b.services.lock.setPin('1234');
    await vault.write('alarm_sound', 'content://media/internal/audio/1');

    final settings = await b.backupSettings();
    expect(settings.keys, isNot(contains('pin_hash')));
    expect(settings.keys, isNot(contains('alarm_sound')));
    expect(settings.keys, isNot(contains('last_backup')));
    expect(settings.keys, isNot(contains('trial_start')));
    final bytes = await Backup.export(b.data, 'backup-pass', files: await b.backupFiles(), settings: settings, iterations: 2000);

    // A new phone with its own PIN and defaults.
    final fresh = Rig();
    await fresh.brain.load();
    await fresh.brain.services.lock.setPin('9999');
    await fresh.brain.setPref('money_hidden', 'false');
    final pinBefore = await fresh.brain.services.lock.keys.read('pin_hash');

    final (data, files, back) = await Backup.restore(bytes, 'backup-pass');
    expect(back, isNotNull);
    await fresh.brain.replaceAll(data, files: files, settings: back);
    final n = fresh.brain;
    expect(n.data.notes.single.title, 'পুরনো নোট');
    expect(n.data.emergency.blood, 'B+');
    expect(n.look, Look.dark);
    expect(n.accentKey, 'purple');
    expect(n.english, isTrue);
    expect(n.letterSize, 1.15);
    expect(n.userName, 'সাইফ');
    expect(n.userPhone, '+8801700000000');
    expect(n.district, 'চট্টগ্রাম');
    expect(n.autoPlace, isFalse);
    expect(n.photo, [1, 2, 3]);
    expect(n.quickQuestions, ['আজ কী কাজ?']);
    expect(n.morningAt, 6 * 60);
    expect(n.calendars, contains('hijri'));
    expect(n.text('weather_places'), '["সিলেট"]');
    expect(tempF, isTrue);
    tempF = false;
    expect(n.text('religion'), 'islam');
    expect(n.flag('money_hidden'), isTrue);
    expect(n.text('note_cats'), '["ব্যবসা"]');
    expect(n.text('ask_sleep'), 'true');
    final keys = n.services.lock.keys;
    expect(await keys.read('chat_history'), '[]');
    expect(await keys.read('heir_scope'), 'docs,notes');
    expect(await keys.read('fam_seed'), 'c2VlZA==');
    expect(await n.services.lock.autoLockSeconds(), 120);
    // Stays this phone's own.
    expect(await keys.read('pin_hash'), pinBefore);
    expect(await n.services.lock.checkPin('9999'), isA<PinOk>());
    expect(await keys.read('alarm_sound'), isNull);
    expect(n.text('last_backup'), isEmpty);
  });

  test('a setting the backup does not have goes back to its default; an older backup leaves settings alone', () async {
    final old = Rig();
    await old.brain.load();
    final plain = await Backup.export(old.brain.data, 'p-12345678', settings: await old.brain.backupSettings(), iterations: 2000);
    final older = await Backup.export(old.brain.data, 'p-12345678', iterations: 2000);

    final phone = Rig();
    await phone.brain.load();
    await phone.brain.setUserName('রহিম');
    await phone.brain.setPref('money_hidden', 'true');
    await phone.brain.setLook(Look.dark);

    final (d1, f1, s1) = await Backup.restore(older, 'p-12345678');
    expect(s1, isNull);
    await phone.brain.replaceAll(d1, files: f1, settings: s1);
    expect(phone.brain.userName, 'রহিম');
    expect(phone.brain.look, Look.dark);

    final (d2, f2, s2) = await Backup.restore(plain, 'p-12345678');
    await phone.brain.replaceAll(d2, files: f2, settings: s2);
    expect(phone.brain.userName, '');
    expect(phone.brain.flag('money_hidden'), isFalse);
    expect(phone.brain.look, Look.sun);
  });

  test('changing a setting or the photo makes the automatic Drive backup run again; opening the app does not', () async {
    final rig = Rig();
    await rig.brain.load();
    final b = rig.brain..driveOn = true;
    await b.setPref('usage_days', '{}');
    expect(await b.services.lock.keys.read('drive_dirty'), isNot('true'));
    await b.setPref('calendars', 'bn');
    expect(await b.services.lock.keys.read('drive_dirty'), 'true');
    expect(jsonDecode(jsonEncode(Brain.backupKeys)), contains('user_name'));
  });
}
