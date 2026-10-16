/// What the app shares with other people through our server: feedback
/// conversations with our team, and blood requests between members. Only
/// what the user writes or attaches here goes; none of their records.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'google_account.dart';

/// A photo or PDF on a message (its bytes are fetched when opened).
class Attachment {
  const Attachment(this.name, this.mime, this.size);
  final String name;
  final String mime;
  final int size;
  bool get image => mime.startsWith('image/');

  static Attachment? fromJson(Object? j) =>
      j is Map ? Attachment('${j['name'] ?? 'file'}', '${j['mime'] ?? ''}', (j['size'] as num?)?.toInt() ?? 0) : null;
}

class FeedbackMessage {
  const FeedbackMessage({required this.id, required this.fromUs, required this.text, required this.at, this.admin = '', this.file});
  final int id;

  /// Written by our team (otherwise by the user).
  final bool fromUs;
  final String admin;
  final String text;
  final DateTime at;
  final Attachment? file;

  static FeedbackMessage fromJson(Map<String, dynamic> j) => FeedbackMessage(
        id: (j['id'] as num).toInt(),
        fromUs: j['from'] == 'admin',
        admin: '${j['admin'] ?? ''}',
        text: '${j['text'] ?? ''}',
        at: DateTime.tryParse('${j['created']}')?.toLocal() ?? DateTime.now(),
        file: Attachment.fromJson(j['file']),
      );
}

class FeedbackThread {
  const FeedbackThread({required this.id, required this.kind, required this.kindLabel, required this.text, required this.updated, required this.status, this.unread = false, this.lastFromUs = false, this.lastText = '', this.count = 1});
  final int id;
  final String kind;
  final String kindLabel;
  final String text;
  final DateTime updated;
  final String status;

  /// Our team answered and the user has not opened it yet.
  final bool unread;
  final bool lastFromUs;
  final String lastText;
  final int count;

  static FeedbackThread fromJson(Map<String, dynamic> j) {
    final last = j['last'];
    return FeedbackThread(
      id: (j['id'] as num).toInt(),
      kind: '${j['kind']}',
      kindLabel: '${j['kind_label'] ?? ''}',
      text: '${j['text'] ?? ''}',
      updated: DateTime.tryParse('${j['updated'] ?? j['created']}')?.toLocal() ?? DateTime.now(),
      status: '${j['status']}',
      unread: j['unread'] == true,
      lastFromUs: last is Map && last['from'] == 'admin',
      lastText: last is Map ? '${last['text'] ?? ''}' : '',
      count: (j['count'] as num?)?.toInt() ?? 1,
    );
  }
}

/// The user's blood-donor profile on the server (only after they opt in).
class DonorProfile {
  const DonorProfile({this.on = false, this.blood = '', this.district = '', this.lastDonated, this.phone = ''});
  final bool on;
  final String blood;
  final String district;
  final DateTime? lastDonated;
  final String phone;

  static DonorProfile fromJson(Object? j) => j is Map
      ? DonorProfile(
          on: j['on'] == true,
          blood: '${j['blood'] ?? ''}',
          district: '${j['district'] ?? ''}',
          lastDonated: DateTime.tryParse('${j['last_donated'] ?? ''}'),
          phone: '${j['phone'] ?? ''}',
        )
      : const DonorProfile();
}

class BloodDonor {
  const BloodDonor(this.name, this.phone, this.note);
  final String name;
  final String phone;
  final String note;
}

class BloodRequest {
  const BloodRequest({
    required this.id,
    required this.mine,
    required this.by,
    required this.blood,
    required this.bags,
    required this.district,
    required this.needBy,
    required this.phone,
    required this.status,
    this.patient = '',
    this.hospital = '',
    this.note = '',
    this.accepted = 0,
    this.iAccepted = false,
    this.donors = const [],
  });
  final int id;
  final bool mine;
  final String by;
  final String patient;
  final String blood;
  final int bags;
  final String district;
  final String hospital;
  final DateTime needBy;
  final String phone;
  final String note;

  /// open, done, cancelled or expired.
  final String status;
  final int accepted;
  final bool iAccepted;

  /// Who said yes, with their numbers — only on the asker's own requests.
  final List<BloodDonor> donors;

  bool get open => status == 'open';

  static BloodRequest fromJson(Map<String, dynamic> j) => BloodRequest(
        id: (j['id'] as num).toInt(),
        mine: j['mine'] == true,
        by: '${j['by'] ?? ''}',
        patient: '${j['patient'] ?? ''}',
        blood: bloodLabel('${j['blood']}'),
        bags: (j['bags'] as num?)?.toInt() ?? 1,
        district: '${j['district'] ?? ''}',
        hospital: '${j['hospital'] ?? ''}',
        needBy: DateTime.tryParse('${j['need_by']}')?.toLocal() ?? DateTime.now(),
        phone: '${j['phone'] ?? ''}',
        note: '${j['note'] ?? ''}',
        status: '${j['status'] ?? 'open'}',
        accepted: (j['accepted'] as num?)?.toInt() ?? 0,
        iAccepted: j['i_accepted'] == true,
        donors: [
          for (final d in (j['donors'] as List? ?? const []))
            if (d is Map) BloodDonor('${d['name'] ?? ''}', '${d['phone'] ?? ''}', '${d['note'] ?? ''}'),
        ],
      );
}

/// "A−" (as the app writes it) ↔ "A-" (as the server keeps it).
String bloodKey(String g) => g.replaceAll('−', '-').replaceAll(' ', '').toUpperCase();
String bloodLabel(String g) => g.replaceAll('-', '−');

/// A feature wish, a problem, or an answer — with an optional photo or PDF.
class OutgoingFile {
  const OutgoingFile(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
  Map<String, Object?> toJson() => {'name': name, 'data': base64Encode(bytes)};
}

/// The calls, through [AccountServer.send] with the phone's session.
class Community {
  Community(this.server, this.session);
  final AccountServer server;
  final String Function() session;

  Future<ServerReply> _send(String method, String path, [Map<String, Object?>? body]) => server.send(method, path, session(), body);

  // Feedback.
  Future<(List<FeedbackThread>, String?)> threads() async {
    final r = await _send('GET', '/feedback');
    return ([for (final j in (r.data['feedback'] as List? ?? const [])) FeedbackThread.fromJson(j as Map<String, dynamic>)], r.error);
  }

  Future<(FeedbackThread?, List<FeedbackMessage>, String?)> thread(int id) async {
    final r = await _send('GET', '/feedback/$id');
    if (!r.ok) return (null, const <FeedbackMessage>[], r.error);
    return (
      FeedbackThread.fromJson(r.data['feedback'] as Map<String, dynamic>),
      [for (final j in (r.data['messages'] as List? ?? const [])) FeedbackMessage.fromJson(j as Map<String, dynamic>)],
      null,
    );
  }

  /// A new conversation: its id, or the reason it did not go.
  Future<(int?, String?)> startFeedback({required String kind, required String text, required String appVersion, OutgoingFile? file}) async {
    final r = await _send('POST', '/feedback', {'kind': kind, 'text': text, 'app_version': appVersion, if (file != null) 'file': file.toJson()});
    return (r.ok ? (r.data['id'] as num?)?.toInt() : null, r.error);
  }

  Future<String?> reply(int threadId, String text, {OutgoingFile? file}) async =>
      (await _send('POST', '/feedback/$threadId/reply', {'text': text, if (file != null) 'file': file.toJson()})).error;

  Future<(Uint8List?, String?)> file(int messageId) async {
    final r = await _send('GET', '/feedback/file/$messageId');
    if (!r.ok) return (null, r.error);
    try {
      return (base64Decode('${r.data['data']}'), null);
    } catch (_) {
      return (null, 'ফাইলটা খোলা গেল না');
    }
  }

  // Blood.
  Future<(DonorProfile, String?)> donor() async {
    final r = await _send('GET', '/blood/donor');
    return (DonorProfile.fromJson(r.data['donor']), r.error);
  }

  Future<(DonorProfile, String?)> setDonor({required bool on, String blood = '', String district = '', DateTime? lastDonated, String phone = ''}) async {
    final r = await _send('POST', '/blood/donor', {
      'on': on,
      if (on) ...{
        'blood': bloodKey(blood),
        'district': district,
        'phone': phone,
        if (lastDonated != null) 'last_donated': '${lastDonated.year.toString().padLeft(4, '0')}-${lastDonated.month.toString().padLeft(2, '0')}-${lastDonated.day.toString().padLeft(2, '0')}',
      },
    });
    return (DonorProfile.fromJson(r.data['donor']), r.error);
  }

  /// scope: near (what this donor can give to), district, or mine.
  Future<(List<BloodRequest>, String?)> requests({String scope = 'near', String district = '', String blood = ''}) async {
    final q = [
      'scope=$scope',
      if (district.isNotEmpty) 'district=${Uri.encodeQueryComponent(district)}',
      if (blood.isNotEmpty) 'blood=${Uri.encodeQueryComponent(bloodKey(blood))}',
    ].join('&');
    final r = await _send('GET', '/blood/requests?$q');
    return ([for (final j in (r.data['requests'] as List? ?? const [])) BloodRequest.fromJson(j as Map<String, dynamic>)], r.error);
  }

  /// A new request: how many donors were told, or the reason it did not go.
  Future<(int?, String?)> ask({required String blood, required int bags, required String district, required String hospital, required DateTime needBy, required String phone, String patient = '', String note = ''}) async {
    final r = await _send('POST', '/blood/requests', {
      'blood': bloodKey(blood),
      'bags': bags,
      'district': district,
      'hospital': hospital,
      'need_by': needBy.toUtc().toIso8601String(),
      'phone': phone,
      'patient': patient,
      'note': note,
    });
    if (r.status == 400) return (null, 'রক্তের গ্রুপ, জেলা, ঠিক মোবাইল নম্বর আর ৩০ দিনের মধ্যের তারিখ দিন');
    if (r.status == 429) return (null, 'একসাথে ৩টার বেশি অনুরোধ খোলা রাখা যায় না');
    return (r.ok ? (r.data['notified'] as num?)?.toInt() ?? 0 : null, r.error);
  }

  Future<(BloodRequest?, String?)> act(int id, String what, {String phone = '', String note = '', String status = 'done'}) async {
    final r = await _send('POST', '/blood/requests/$id/$what', {'phone': phone, 'note': note, 'status': status});
    if (r.status == 400 && r.data['code'] == 'phone') return (null, 'আপনার মোবাইল নম্বর দিন — যিনি অনুরোধ করেছেন, তিনি যোগাযোগ করবেন');
    final j = r.data['request'];
    return (j is Map<String, dynamic> ? BloodRequest.fromJson(j) : null, r.error);
  }
}
