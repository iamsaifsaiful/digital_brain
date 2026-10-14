import 'package:flutter/services.dart';

import '../models/models.dart';

/// Messages from other apps, read from their notifications on the phone
/// (Android's notification access). Nothing leaves the phone.
abstract class InboxSource {
  /// The user has turned on notification access for the app.
  Future<bool> hasAccess();

  /// Opens the phone's notification-access page for this app.
  Future<void> openAccess();

  /// Opens this app's info page ("Allow restricted settings" lives in its ⋮ menu).
  Future<void> openAppInfo();

  /// New messages since the last call (removed from the waiting list).
  Future<List<InboxMessage>> take();

  /// Which apps to read, and the master switch.
  Future<void> setApps(List<String> apps, {required bool on});

  /// Sends [text] with the message's own reply button, if it is still on the phone.
  Future<bool> reply(InboxMessage m, String text);
  Future<bool> canReply(InboxMessage m);

  /// Opens the app the message came from.
  Future<bool> openApp(String app);
}

/// The apps that can be read (package → name), in the order shown.
const inboxApps = <String, String>{
  'com.whatsapp': 'WhatsApp',
  'com.whatsapp.w4b': 'WhatsApp Business',
  'org.telegram.messenger': 'Telegram',
  'org.thunderdog.challegram': 'Telegram X',
  'com.imo.android.imoim': 'imo',
  'com.imo.android.imoimbeta': 'imo',
  'com.imo.android.imoimhd': 'imo HD',
  'com.imo.android.imous': 'imo Lite',
  'com.facebook.orca': 'Messenger',
  'com.facebook.mlite': 'Messenger Lite',
  'com.google.android.gm': 'Gmail',
  'com.microsoft.office.outlook': 'Outlook',
  'com.yahoo.mobile.client.android.mail': 'Yahoo Mail',
  'com.samsung.android.email.provider': 'Email',
  'com.google.android.apps.messaging': 'SMS',
  'com.samsung.android.messaging': 'SMS',
  'com.android.mms': 'SMS',
  'com.viber.voip': 'Viber',
  'org.thoughtcrime.securesms': 'Signal',
  'com.skype.raider': 'Skype',
  'com.linkedin.android': 'LinkedIn',
};

/// The names shown as switches (one per name; all its packages go together).
List<String> get inboxAppNames => {for (final v in inboxApps.values) v.replaceAll(RegExp(r' (HD|Lite|X)$'), '')}.toList();

List<String> packagesOf(String name) => [for (final e in inboxApps.entries) if (e.value.replaceAll(RegExp(r' (HD|Lite|X)$'), '') == name) e.key];

class DeviceInbox implements InboxSource {
  static const _ch = MethodChannel('my_assistant/inbox');

  @override
  Future<bool> hasAccess() async {
    try {
      return await _ch.invokeMethod<bool>('access') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openAccess() async {
    try {
      await _ch.invokeMethod<void>('openAccess');
    } catch (_) {}
  }

  @override
  Future<void> openAppInfo() async {
    try {
      await _ch.invokeMethod<void>('appInfo');
    } catch (_) {}
  }

  @override
  Future<List<InboxMessage>> take() async {
    try {
      final raw = await _ch.invokeMethod<List<Object?>>('take') ?? const [];
      return [
        for (final r in raw)
          if (r is Map)
            InboxMessage(
              id: '${r['id']}',
              app: '${r['app']}',
              appName: '${r['appName']}',
              chat: '${r['chat'] ?? ''}',
              from: '${r['from'] ?? ''}',
              text: '${r['text'] ?? ''}',
              at: DateTime.fromMillisecondsSinceEpoch((r['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
              key: '${r['key'] ?? ''}',
              group: r['group'] == true,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> setApps(List<String> apps, {required bool on}) async {
    try {
      await _ch.invokeMethod<void>('setApps', {'apps': apps, 'on': on});
    } catch (_) {}
  }

  @override
  Future<bool> reply(InboxMessage m, String text) async {
    try {
      return await _ch.invokeMethod<bool>('reply', {'key': m.key, 'text': text}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canReply(InboxMessage m) async {
    if (m.key.isEmpty) return false;
    try {
      return await _ch.invokeMethod<bool>('canReply', {'key': m.key}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openApp(String app) async {
    try {
      return await _ch.invokeMethod<bool>('openApp', {'app': app}) ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// For tests (and phones without the feature).
class FakeInbox implements InboxSource {
  bool access = false;
  final waiting = <InboxMessage>[];
  final sent = <(String, String)>[];
  List<String> apps = const [];
  bool on = true;

  @override
  Future<bool> hasAccess() async => access;
  @override
  Future<void> openAccess() async => access = true;
  @override
  Future<void> openAppInfo() async {}
  @override
  Future<List<InboxMessage>> take() async {
    final out = List.of(waiting);
    waiting.clear();
    return out;
  }

  @override
  Future<void> setApps(List<String> apps, {required bool on}) async {
    this.apps = apps;
    this.on = on;
  }

  @override
  Future<bool> reply(InboxMessage m, String text) async {
    sent.add((m.id, text));
    return true;
  }

  @override
  Future<bool> canReply(InboxMessage m) async => m.key.isNotEmpty;
  @override
  Future<bool> openApp(String app) async => true;
}
