// ফ্যামিলি (Pro): members linked by e-mail; what each lets the other do;
// to-dos, reminders, medicine reminders and notes sent sealed; live location
// for those allowed; heirs and the sealed copy they may open
// (tool/wordpress/my-assistant-accounts/family.php; sealing in
// lib/services/family_crypto.dart).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart';

import '../logic/lang.dart';
import '../models/models.dart';
import '../services/crypto.dart' show randomBytes, WrongKey, seal, open;
import '../services/family_crypto.dart';
import '../services/files.dart' show PickedDoc;
import '../services/location_share.dart';
import '../services/trace.dart';
import 'brain.dart';

/// AES-256-GCM with a 32-byte key (lib/services/crypto.dart).
Future<Uint8List> sealBytes(List<int> clear, List<int> key) => seal(clear, key);
Future<Uint8List> openBytes(List<int> sealed, List<int> key) => open(sealed, key);

/// What one member may let the other do (the order shown).
const familyPerms = ['task', 'reminder', 'medicine', 'note', 'location'];

String familyPermLabel(String p) => switch (p) {
      'task' => tr('আমার জন্য কাজ যোগ করা'),
      'reminder' => tr('আমার জন্য রিমাইন্ডার দেওয়া'),
      'medicine' => tr('আমার ওষুধের রিমাইন্ডার দেওয়া'),
      'note' => tr('আমাকে নোট পাঠানো'),
      'location' => tr('আমার লাইভ লোকেশন দেখা'),
      _ => p,
    };

/// What the heirs' copy may hold (the member chooses; passwords and health are off unless ticked).
const heirParts = {
  'money': ['ledger', 'cash', 'accounts', 'transfers', 'goals', 'installments', 'projects', 'shops', 'receipts'],
  'notes': ['notes', 'memories'],
  'docs': ['docs'],
  'tasks': ['tasks', 'reminders', 'specialDays'],
  'contacts': ['contacts'],
  'health': ['members', 'health', 'medicines', 'vaccines', 'emergency'],
  'vault': ['vault'],
};
const heirPartsDefault = ['money', 'notes', 'docs', 'tasks', 'contacts'];

String heirPartLabel(String p) => switch (p) {
      'money' => tr('টাকা: আয়-ব্যয়, ধার-দেনা, অ্যাকাউন্ট, সঞ্চয়, কিস্তি'),
      'notes' => tr('নোট আর “মনে রেখো”'),
      'docs' => tr('ডকুমেন্টের তালিকা ও লেখা (ছবি নয়)'),
      'tasks' => tr('কাজ, রিমাইন্ডার, বিশেষ দিন'),
      'contacts' => tr('নম্বর'),
      'health' => tr('স্বাস্থ্য ও ওষুধ'),
      'vault' => tr('পাসওয়ার্ড ও ভল্ট'),
      _ => p,
    };

class FamilyClaim {
  const FamilyClaim(this.id, this.status, this.openAt);
  final int id;

  /// review (an admin checks), waiting (14 days), open, rejected, cancelled.
  final String status;
  final DateTime? openAt;
  static FamilyClaim? fromJson(Object? j) => j is Map ? FamilyClaim((j['id'] as num?)?.toInt() ?? 0, '${j['status']}', DateTime.tryParse('${j['open_at'] ?? ''}')?.toLocal()) : null;
}

class FamilyLink {
  FamilyLink.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        status = '${j['status']}',
        incoming = j['incoming'] == true,
        name = '${j['name'] ?? ''}',
        email = '${j['email'] ?? ''}',
        iCall = '${j['i_call'] ?? ''}',
        theyCall = '${j['they_call'] ?? ''}',
        iAllow = [for (final p in (j['i_allow'] as List? ?? const [])) '$p'],
        theyAllow = [for (final p in (j['they_allow'] as List? ?? const [])) '$p'],
        theyAreMyHeir = j['they_are_my_heir'] == true,
        iAmTheirHeir = j['i_am_their_heir'] == true,
        iOpened = j['i_opened'] == true,
        theyOpened = j['they_opened'] == true,
        theirKey = '${j['their_key'] ?? ''}',
        packageAt = j['package'] is Map ? DateTime.tryParse('${(j['package'] as Map)['at']}')?.toLocal() : null,
        claim = FamilyClaim.fromJson(j['claim']),
        canOpen = j['can_open'] == true;
  final int id;

  /// pending or active.
  final String status;

  /// An invitation to me, not answered yet.
  final bool incoming;
  final String name;
  final String email;

  /// How I call them ("আম্মা"), and how they call me.
  final String iCall;
  final String theyCall;
  final List<String> iAllow;
  final List<String> theyAllow;
  final bool theyAreMyHeir;
  final bool iAmTheirHeir;

  /// I let them open my copy now (or they let me open theirs).
  final bool iOpened;
  final bool theyOpened;
  final String theirKey;
  final DateTime? packageAt;
  final FamilyClaim? claim;
  final bool canOpen;

  bool get active => status == 'active';
  String get title => iCall.isEmpty ? name : '$iCall · $name';
}

class FamilyState extends ChangeNotifier {
  FamilyState(this.brain);
  final Brain brain;

  List<FamilyLink> links = [];
  List<(int, String, DateTime?)> claimsOnMe = [];
  bool pro = false;
  bool loaded = false;
  String? error;

  /// What came in lately (shown on the ফ্যামিলি page): (from, what).
  final List<(String, String)> received = [];

  FamilyKeys? _keys;

  Future<String?> _get(String k) async {
    try {
      return await brain.services.lock.keys.read(k);
    } catch (_) {
      return null;
    }
  }

  Future<void> _put(String k, String? v) async {
    try {
      if (v == null) {
        await brain.services.lock.keys.delete(k);
      } else {
        await brain.services.lock.keys.write(k, v);
      }
    } catch (_) {}
  }

  Future<FamilyKeys> keys() async {
    final k = _keys;
    if (k != null) return k;
    final seed = await _get('fam_seed');
    final got = seed != null && seed.isNotEmpty ? await FamilyKeys.fromSeed(base64Decode(seed)) : await FamilyKeys.generate();
    if (seed == null || seed.isEmpty) await _put('fam_seed', base64Encode(got.seed));
    return _keys = got;
  }

  String get _session => brain.services.ai.session;
  bool get _online => _session.isNotEmpty && brain.services.server.configured;

  Future<Map<String, dynamic>?> _send(String method, String path, [Map<String, Object?>? body]) async {
    final r = await brain.services.server.send(method, path, _session, body);
    if (r.status == 402) {
      error = tr('ফ্যামিলি প্রিমিয়ামে — কাউকে যুক্ত করতে বা কিছু পাঠাতে প্রিমিয়াম লাগবে');
      notifyListeners();
      return null;
    }
    if (!r.ok) {
      // The site's plugin is older than the family part.
      if (r.status == 404 && r.data['code'] == 'rest_no_route') {
        error = tr('সার্ভারে ফ্যামিলি এখনো চালু হয়নি — সাইটের প্লাগিন হালনাগাদ করতে হবে');
        notifyListeners();
        return null;
      }
      error = switch (r.status) {
        409 => tr('আগেই ফ্যামিলিতে আছেন (বা অনুরোধ আগেই গেছে)'),
        403 => tr('তিনি এটার অনুমতি দেননি'),
        429 => tr('ফ্যামিলিতে ২০ জনের বেশি রাখা যায় না'),
        _ => r.error,
      };
      notifyListeners();
      return null;
    }
    error = null;
    return r.data;
  }

  void _take(Map<String, dynamic> d) {
    pro = d['pro'] == true;
    links = [for (final j in (d['links'] as List? ?? const [])) FamilyLink.fromJson((j as Map).cast<String, dynamic>())];
    claimsOnMe = [
      for (final c in (d['claims_on_me'] as List? ?? const []))
        if (c is Map) ((c['id'] as num).toInt(), '${c['by'] ?? ''}', DateTime.tryParse('${c['open_at'] ?? ''}')?.toLocal()),
    ];
    loaded = true;
    notifyListeners();
  }

  /// Publishes this phone's key if the server has another, loads the family,
  /// takes in what came, keeps location sharing and the heirs' copy up to date.
  Future<void> refresh({bool deep = true}) async {
    if (!_online) return;
    final d = await _send('GET', '/family');
    if (d == null) return;
    final k = await keys();
    if ('${d['my_key'] ?? ''}' != k.publicB64) await _send('POST', '/family/key', {'pubkey': k.publicB64});
    _take(d);
    if (!deep) return;
    await receive();
    await syncLocation();
    await uploadPackage();
  }

  Future<bool> invite(String email, String relation, List<String> allow) async {
    final d = await _send('POST', '/family/invite', {'email': email.trim(), 'relation': relation.trim(), 'allow': allow});
    if (d != null) _take(d);
    return d != null;
  }

  Future<void> answer(FamilyLink l, bool yes, {String relation = '', List<String> allow = const []}) async {
    final d = await _send('POST', '/family/${l.id}/${yes ? 'accept' : 'decline'}', {'relation': relation.trim(), 'allow': allow});
    if (d != null) _take(d);
    if (yes) await syncLocation();
  }

  Future<void> remove(FamilyLink l) async {
    final d = await _send('POST', '/family/${l.id}/remove');
    if (d != null) _take(d);
    await _put('fam_lockey_${l.id}', null);
    await syncLocation();
    await uploadPackage(force: true);
  }

  Future<void> setAllow(FamilyLink l, {List<String>? allow, String? relation, bool? heir, bool? openNow}) async {
    final d = await _send('POST', '/family/${l.id}/allow', {
      if (allow != null) 'allow': allow,
      if (relation != null) 'relation': relation,
      if (heir != null) 'heir': heir,
      if (openNow != null) 'open_now': openNow,
    });
    if (d != null) _take(d);
    if (allow != null) await syncLocation();
    if (heir != null) await uploadPackage(force: true);
  }

  /// A to-do, a reminder, a medicine reminder or a note for [l], sealed for their phone.
  Future<bool> send(FamilyLink l, String kind, Map<String, Object?> payload) async {
    if (l.theirKey.isEmpty) {
      error = tr('তাঁর ফোন এখনো ফ্যামিলির জন্য তৈরি হয়নি — তাঁকে একবার অ্যাপ খুলতে বলুন');
      notifyListeners();
      return false;
    }
    final from = l.theyCall.isNotEmpty ? l.theyCall : (brain.userName.isNotEmpty ? brain.userName : '');
    final sealed = await sealJsonFor({...payload, 'from': from}, l.theirKey);
    return await _send('POST', '/family/items', {'link': l.id, 'kind': kind, 'sealed': sealed}) != null;
  }

  /// Takes in what family members sent: each becomes this phone's own to-do,
  /// reminder, medicine or note. Returns how many.
  Future<int> receive() async {
    if (!_online) return 0;
    final d = await _send('GET', '/family/items');
    final items = (d?['items'] as List?) ?? const [];
    if (items.isEmpty) return 0;
    final k = await keys();
    final done = <int>[];
    var n = 0;
    for (final it in items.cast<Map>()) {
      final id = (it['id'] as num).toInt();
      done.add(id);
      try {
        final p = await openJson('${it['sealed']}', k);
        final kind = '${it['kind']}';
        if (kind == 'lockey') {
          await _put('fam_lockey_${it['link']}', '${p['key']}');
          continue;
        }
        final what = await _apply(kind, p);
        if (what != null) {
          received.insert(0, ('${p['from'] ?? ''}', what));
          n++;
        }
      } on WrongKey {
        // Sealed for an older key of this phone: cannot be opened; dropped.
      } catch (e) {
        Trace.log('family', 'item not taken', {'error': '$e'});
      }
    }
    if (done.isNotEmpty) await _send('POST', '/family/items/ack', {'ids': done});
    if (n > 0) notifyListeners();
    return n;
  }

  DateTime? _day(Object? v) => DateTime.tryParse('${v ?? ''}');

  Future<String?> _apply(String kind, Map<String, dynamic> p) async {
    final from = '${p['from'] ?? ''}';
    final by = from.isEmpty ? tr('ফ্যামিলি থেকে') : trf('{0} দিয়েছেন', [from]);
    final title = '${p['title'] ?? ''}'.trim();
    final note = ['${p['note'] ?? ''}'.trim(), by].where((x) => x.isNotEmpty).join(' · ');
    switch (kind) {
      case 'task':
        if (title.isEmpty) return null;
        await brain.saveTask(Task(title: title, due: _day(p['date']), note: note));
        return trf('কাজ: {0}', [title]);
      case 'reminder':
        final day = _day(p['date']);
        if (title.isEmpty || day == null) return null;
        await brain.saveReminder(Reminder(title: title, date: DateTime(day.year, day.month, day.day), hour: (p['hour'] as num?)?.toInt() ?? 9, minute: (p['minute'] as num?)?.toInt() ?? 0, note: note));
        return trf('রিমাইন্ডার: {0}', [title]);
      case 'medicine':
        final times = [for (final t in (p['times'] as List? ?? const [])) if (t is num && t >= 0 && t < 24 * 60) t.toInt()];
        if (title.isEmpty || times.isEmpty) return null;
        await brain.saveMedicine(Medicine(name: title, dose: (p['dose'] as num?)?.toInt() ?? 1, times: times, until: _day(p['until']), note: note));
        return trf('ওষুধ: {0}', [title]);
      case 'note':
        final body = '${p['body'] ?? ''}';
        if (title.isEmpty && body.isEmpty) return null;
        await brain.saveNote(Note(title: title, body: body.isEmpty ? note : '$body\n\n$by', category: tr('ফ্যামিলি')));
        return trf('নোট: {0}', [title.isEmpty ? body : title]);
    }
    return null;
  }

  // ── Live location ──

  /// The location key goes (sealed) to everyone allowed to see where I am;
  /// a new key when someone is taken off. The phone answers by itself.
  Future<void> syncLocation() async {
    if (!_online) return;
    final viewers = [for (final l in links) if (l.active && l.iAllow.contains('location')) l];
    final before = ((await _get('fam_loc_viewers')) ?? '').split(',').where((x) => x.isNotEmpty).toSet();
    final now = {for (final l in viewers) '${l.id}'};
    if (viewers.isEmpty) {
      await LocationShareChannel.configure(on: false);
      await _put('fam_lockey_own', null);
      await _put('fam_loc_viewers', '');
      return;
    }
    var key = await _get('fam_lockey_own');
    final rotate = key == null || key.isEmpty || before.difference(now).isNotEmpty;
    if (rotate) key = base64Encode(randomBytes(32));
    for (final l in viewers) {
      if ((rotate || !before.contains('${l.id}')) && l.theirKey.isNotEmpty) {
        final sealed = await sealJsonFor({'key': key}, l.theirKey);
        await _send('POST', '/family/items', {'link': l.id, 'kind': 'lockey', 'sealed': sealed});
      }
    }
    await _put('fam_lockey_own', key);
    await _put('fam_loc_viewers', now.join(','));
    await LocationShareChannel.configure(on: true, key: key, session: _session, base: brain.services.server.base);
  }

  /// Asks [l]'s phone where it is; waits up to [wait] for the answer.
  /// Returns {lat, lon, acc, at, battery, seen (when the server got it)} or null.
  Future<Map<String, dynamic>?> locate(FamilyLink l, {Duration wait = const Duration(seconds: 30)}) async {
    final key = await _get('fam_lockey_${l.id}');
    if (key == null || key.isEmpty) {
      await receive(); // the key may have just come
    }
    final k = await _get('fam_lockey_${l.id}');
    if (k == null || k.isEmpty) {
      error = tr('তাঁর লোকেশনের চাবি এখনো আসেনি — তাঁকে একবার অ্যাপ খুলতে বলুন');
      notifyListeners();
      return null;
    }
    final asked = DateTime.now().toUtc();
    final before = await _location(l, k);
    if (await _send('POST', '/family/${l.id}/locate') == null) return before;
    final end = DateTime.now().add(wait);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final p = await _location(l, k);
      final seen = p?['seen'] as DateTime?;
      if (p != null && seen != null && !seen.isBefore(asked.subtract(const Duration(seconds: 5)))) return p;
    }
    return before;
  }

  Future<Map<String, dynamic>?> _location(FamilyLink l, String key) async {
    final d = await _send('GET', '/family/${l.id}/location');
    final s = '${d?['sealed'] ?? ''}';
    if (s.isEmpty) return null;
    try {
      final p = await openPlace(s, base64Decode(key));
      return {...p, 'seen': DateTime.tryParse('${d?['at'] ?? ''}')};
    } catch (_) {
      return null;
    }
  }

  // ── Heirs ──

  Future<List<String>> heirScope() async {
    final s = await _get('heir_scope');
    return s == null ? List.of(heirPartsDefault) : s.split(',').where(heirParts.containsKey).toList();
  }

  Future<void> setHeirScope(List<String> parts) async {
    await _put('heir_scope', parts.join(','));
    await uploadPackage(force: true);
  }

  /// The heirs' sealed copy: sent again when the chosen parts changed (at most once a day unless [force]).
  Future<void> uploadPackage({bool force = false}) async {
    if (!_online) return;
    final heirs = {for (final l in links) if (l.active && l.theyAreMyHeir && l.theirKey.isNotEmpty) l};
    if (heirs.isEmpty) {
      if ((await _get('heir_sent')) != null) {
        await _send('DELETE', '/family/package');
        await _put('heir_sent', null);
      }
      return;
    }
    final scope = await heirScope();
    final all = brain.data.toJson();
    // Photos and files of the chosen documents and notes: sealed one by one
    // with a key of their own (kept on this phone, carried in the copy).
    var filesKey = await _get('heir_files_key');
    if (filesKey == null || filesKey.isEmpty) {
      filesKey = base64Encode(randomBytes(32));
      await _put('heir_files_key', filesKey);
    }
    final files = <DocFile>[
      if (scope.contains('docs')) for (final d in brain.data.docs) ...d.files,
      if (scope.contains('notes')) for (final n in brain.data.notes) ...n.files,
    ];
    final parts = <String, Object?>{
      'v': 1,
      'name': brain.userName,
      'at': DateTime.now().toUtc().toIso8601String(),
      'parts': scope,
      'files_key': filesKey,
      for (final p in scope)
        for (final k in heirParts[p]!) if (all[k] != null) k: all[k],
    };
    final digest = await Sha256().hash(utf8.encode(jsonEncode({...parts, 'at': ''})));
    final sig = '${base64Encode(digest.bytes)}:${heirs.map((h) => h.id).join(',')}';
    final last = await _get('heir_sent');
    final lastAt = DateTime.tryParse((await _get('heir_sent_at')) ?? '');
    // Unchanged: not sent again; changed: at most every 6 hours (unless [force]).
    if (!force && (last == sig || (lastAt != null && DateTime.now().difference(lastAt).inHours < 6))) return;
    final (blob, keys) = await sealPackage(parts, {for (final h in heirs) h.id: h.theirKey});
    final r = await _send('POST', '/family/package', {'blob': blob, 'keys': keys, 'files': [for (final f in files) f.id]});
    if (r != null) {
      await _put('heir_sent', sig);
      await _put('heir_sent_at', DateTime.now().toIso8601String());
    }
    await _uploadFiles(files, filesKey);
  }

  /// The photos not sent yet — on Wi-Fi only (they can be many megabytes).
  Future<void> _uploadFiles(List<DocFile> files, String filesKey) async {
    final sent = ((await _get('heir_files_sent')) ?? '').split(',').where((x) => x.isNotEmpty).toSet();
    final want = {for (final f in files) f.id};
    final todo = [for (final f in files) if (!sent.contains(f.id)) f];
    if (todo.isNotEmpty && !await brain.unmetered()) return;
    final key = base64Decode(filesKey);
    for (final f in todo) {
      final bytes = await brain.services.store.loadDocFile(f.id);
      if (bytes == null || bytes.length > 4 * 1024 * 1024) continue;
      final blob = base64Encode(await sealBytes(bytes, key));
      if (await _send('POST', '/family/files', {'id': f.id, 'blob': blob}) != null) sent.add(f.id);
    }
    await _put('heir_files_sent', sent.intersection(want).join(','));
  }

  /// One photo or file of the copy an heir opened ([filesKey] comes in the copy).
  Future<Uint8List?> openFile(FamilyLink l, String fileId, String filesKey) async {
    final d = await _send('GET', '/family/${l.id}/files/$fileId');
    if (d == null) return null;
    try {
      return await openBytes(base64Decode('${d['blob']}'), base64Decode(filesKey));
    } catch (_) {
      return null;
    }
  }

  /// The copy an heir may open now: the chosen parts of the member's data.
  Future<Map<String, dynamic>?> openPackage(FamilyLink l) async {
    final d = await _send('GET', '/family/${l.id}/package');
    if (d == null) return null;
    try {
      return await openSealedPackage('${d['blob']}', '${d['key']}', await keys());
    } on WrongKey {
      error = tr('এই ফোনে খোলা গেল না — যে ফোনে ফ্যামিলি চালু করেছিলেন সেখানে খুলুন, অথবা তাঁর পাঠানো নতুন কপির জন্য অপেক্ষা করুন');
      notifyListeners();
      return null;
    }
  }

  /// An heir reports a death, with a photo of the certificate.
  Future<bool> claim(FamilyLink l, PickedDoc doc, String note) async {
    final d = await _send('POST', '/family/${l.id}/claim', {
      'note': note,
      'file': {'name': doc.name, 'data': base64Encode(doc.bytes)},
    });
    if (d != null) _take(d);
    return d != null;
  }

  Future<void> cancelClaim(int id) async {
    final d = await _send('POST', '/family/claims/$id/cancel');
    if (d != null) _take(d);
  }
}
