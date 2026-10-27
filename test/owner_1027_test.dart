// Owner, 27 Oct: notifications written on the site did not come. The server
// now pushes the ones without a condition itself (the phone is told which,
// and does not plan them again), and the site's own notices go first under
// the daily cap.
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/server_notices.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 27, 9);

  test('a notice the server pushes is not planned on the phone again', () {
    final a = ServerNotice.fromJson({'id': 1, 'title': 'সাইট থেকে', 'kind': 'daily', 'time': '20:00', 'pushed': true})!;
    final b = ServerNotice.fromJson({'id': 2, 'title': 'শর্তের', 'kind': 'daily', 'time': '20:00', 'cond': 'no_tasks'})!;
    expect(a.pushed, isTrue);
    expect(ServerNotice.fromJson(a.toJson())!.pushed, isTrue, reason: 'kept on the phone between openings');
    final planned = serverNotices([a, b], AppData(), now);
    expect(planned.where((p) => p.title == 'সাইট থেকে'), isEmpty);
    expect(planned.where((p) => p.title == 'শর্তের'), isNotEmpty);
  });

  test("the site's notice is kept when the day's cap is full", () {
    final n = ServerNotice.fromJson({'id': 3, 'title': 'আজ বৃহস্পতিবার', 'kind': 'daily', 'time': '11:11'})!;
    final all = assistantNotices(AppData(), now, AssistantPrefs(dailyCap: 1, server: [n]));
    final today = all.where((p) => p.at.day == 27).toList();
    expect(today.map((p) => p.title), contains('আজ বৃহস্পতিবার'));
  });
}
