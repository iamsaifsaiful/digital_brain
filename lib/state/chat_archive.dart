import 'dart:convert';

import '../logic/parser.dart';
import '../services/crypto.dart';
import 'chat.dart';

/// One earlier conversation, kept only on this phone (in the encrypted key
/// store), for the "আগের কথা" list in the menu.
class SavedChat {
  SavedChat({required this.id, required this.title, required this.at, required this.messages});

  final String id;
  final String title;
  final DateTime at;
  final List<ChatMessage> messages;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'at': at.millisecondsSinceEpoch,
        'm': [
          for (final m in messages) {'u': m.fromUser, 't': m.text, if (m.info) 'i': true, if (m.facts.isNotEmpty) 'f': m.facts},
        ],
      };

  static SavedChat? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return SavedChat(
        id: '${j['id']}',
        title: '${j['title']}',
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
        messages: [
          for (final m in (j['m'] as List? ?? const []))
            if (m is Map)
              m['u'] == true
                  ? ChatMessage.user('${m['t']}')
                  : ChatMessage.app('${m['t']}', info: m['i'] == true, facts: [for (final f in (m['f'] as List? ?? const [])) '$f']),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// A sentence that held a password or code is never kept as written.
String redactSecret(String text) =>
    mentionsSecret(text) || vaultAddFrom(text) != null ? '[পাসওয়ার্ড বা গোপন কোড — লুকানো]' : text;

/// The "আগের কথা" store: newest first, at most [keep] conversations.
class ChatArchive {
  ChatArchive(this.keys, {this.keep = 30});

  final KeyVault keys;
  final int keep;
  static const _key = 'chat_history';

  Future<List<SavedChat>> load() async {
    try {
      final raw = await keys.read(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(SavedChat.fromJson).whereType<SavedChat>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<SavedChat> all) async {
    await keys.write(_key, jsonEncode([for (final c in all.take(keep)) c.toJson()]));
  }

  /// Adds or updates [c] (by id) at the top.
  Future<List<SavedChat>> save(SavedChat c) async {
    final all = await load()
      ..removeWhere((x) => x.id == c.id)
      ..insert(0, c);
    await _write(all);
    return all.take(keep).toList();
  }

  Future<List<SavedChat>> remove(String id) async {
    final all = await load()
      ..removeWhere((x) => x.id == id);
    await _write(all);
    return all;
  }

  Future<void> clear() => keys.delete(_key);
}

/// What to keep of a conversation: no logins, no secret sentences, and at
/// most the last 120 messages.
List<ChatMessage> keepable(List<ChatMessage> messages) {
  final out = <ChatMessage>[];
  for (final m in messages) {
    if (m.fromUser) {
      out.add(ChatMessage.user(redactSecret(m.text)));
    } else {
      out.add(ChatMessage.app(m.text, info: m.info, facts: m.facts));
    }
  }
  return out.length > 120 ? out.sublist(out.length - 120) : out;
}

/// "রবিনকে ৫০০০ টাকা ধার দিলাম, আর কাল…" → a short title.
String chatTitle(List<ChatMessage> messages) {
  final first = messages.where((m) => m.fromUser).firstOrNull;
  if (first == null) return 'নতুন কথা';
  final t = redactSecret(first.text).replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > 42 ? '${t.substring(0, 40)}…' : t;
}
