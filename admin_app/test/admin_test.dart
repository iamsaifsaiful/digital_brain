import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_assistant_admin/ai_page.dart';
import 'package:my_assistant_admin/api.dart';
import 'package:my_assistant_admin/bkash.dart';
import 'package:my_assistant_admin/main.dart';

final _now = DateTime.now().toUtc();
String _ago(Duration d) => _now.subtract(d).toIso8601String();

/// A pretend server with what the admin app shows.
class FakeServer {
  final calls = <http.Request>[];
  final payments = <Map<String, Object?>>[
    {'id': 1, 'created': _ago(const Duration(minutes: 30)), 'email': 'rakib.hasan92@gmail.com', 'name': 'রাকিব হাসান', 'phone': '', 'plan': 'বার্ষিক', 'amount': 999, 'method': 'বিকাশ', 'sender': '01712345678', 'trx': 'BJK4Q9X2PL', 'note': '', 'status': 'pending', 'reason': '', 'reviewed_by': '', 'reviewed': null},
    {'id': 2, 'created': _ago(const Duration(hours: 2)), 'email': 'ayesha.s@gmail.com', 'name': 'Ayesha Siddika', 'phone': '', 'plan': 'মাসিক', 'amount': 99, 'method': 'নগদ', 'sender': '01987654321', 'trx': '7NG2KD81QZ', 'note': 'তাড়াতাড়ি চালু করবেন', 'status': 'pending', 'reason': '', 'reviewed_by': '', 'reviewed': null},
  ];

  final feedback = <Map<String, Object?>>[
    {'id': 7, 'created': _ago(const Duration(minutes: 12)), 'updated': _ago(const Duration(minutes: 12)), 'email': 'rakib.hasan92@gmail.com', 'name': 'রাকিব হাসান', 'kind': 'problem', 'kind_label': 'সমস্যা', 'text': 'রাত ১০টার রিমাইন্ডার বাজেনি', 'version': '2.15.0', 'status': 'new', 'count': 1},
  ];
  final messages = <Map<String, Object?>>[
    {'id': 70, 'from': 'member', 'admin': '', 'text': 'রাত ১০টার রিমাইন্ডার বাজেনি', 'created': _ago(const Duration(minutes: 12)), 'file': {'name': 'screen.png', 'mime': 'image/png', 'size': 70}},
  ];
  final replies = <Map<String, dynamic>>[];
  final finAdds = <Map<String, dynamic>>[];
  final finEntries = <Map<String, Object?>>[
    {'id': 1, 'kind': 'expense', 'category': 'সার্ভার ও হোস্টিং', 'amount': 1500, 'on_date': '2026-10-05', 'note': 'হোস্টিং'},
  ];
  final investors = <Map<String, Object?>>[
    {'id': 1, 'name': 'করিম চৌধুরী', 'contact': '01711000000', 'amount': 200000, 'share': '10', 'on_date': '2026-09-01', 'note': ''},
  ];
  final saved = <Map<String, dynamic>>[];
  final printLinks = <Map<String, dynamic>>[];
  final opened = <String>[];
  final memberQueries = <Map<String, String>>[];
  final inboxSet = <String>[];
  final bkashManual = <Map<String, dynamic>>[];
  final bkash = <String, Object?>{
    'auto': true, 'phone_set': true, 'last_sms': _ago(const Duration(minutes: 5)),
    'received': <Map<String, Object?>>[
      {'id': 1, 'trx': '9A7KX2PQ1M', 'amount': 999, 'sender': '01712345678', 'at': _ago(const Duration(minutes: 5)), 'source': 'sms', 'status': 'matched', 'status_label': 'মিলেছে — প্রিমিয়াম চালু', 'payment_id': 1},
      {'id': 2, 'trx': 'SHORTPAY01', 'amount': 500, 'sender': '01700000000', 'at': _ago(const Duration(hours: 1)), 'source': 'sms', 'status': 'short', 'status_label': 'টাকা কম', 'payment_id': 3},
    ],
  };
  final labels = <Map<String, dynamic>>[];
  final decisions = <Map<String, dynamic>>[];
  final aiSettings = <String, Object?>{
    'nlu': {'mode': 'shadow', 'pct': 100, 'free_model': 'gemini-3.1-flash-lite', 'pro_model': 'claude-haiku-5-5', 'escalate_model': 'claude-sonnet-5-5', 'free_per_user': 20, 'pro_per_user': 60},
    'ai_on': true, 'budgets': {'auto': true, 'free': {'day': 0.2, 'month': 3}, 'pro': {'day': 0.09, 'month': 1.3}}, 'member_cap_usd': 0.2047, 'usd_bdt': 122,
    'anthropic_key': 'saved', 'gemini_key': true, 'prompt_ver': 'v1',
    'owner': true, 'ai_per_user': 30, 'ai_per_day': 2000, 'anthropic_tail': 'AbCd', 'gemini_source': 'saved', 'gemini_tail': 'WxYz',
    'prices': {'claude-haiku-5-5': {'in': 1, 'cw': 1.25, 'cr': 0.1, 'out': 5}}, 'ci_key': 'k' * 48,
  };
  final reviews = <Map<String, Object?>>[
    {'id': 11, 'created': '2026-10-22 04:00:00', 'state': 'idle', 'text': '<নাম১>কে ৫০০ টাকা দিলাম', 'phone': ['cash_add'], 'phone_conf': 0.62, 'cloud': ['ledger_add'], 'cloud_provider': 'gemini', 'final': ['ledger_add'], 'signal': 'edited'},
  ];
  final models = <Map<String, Object?>>[
    {'version': 'm2', 'url': 'https://x/m2.tflite', 'sha256': 'a' * 64, 'size': 14068808, 'rollout_pct': 0, 'status': 'draft', 'created': '2026-10-22 04:00:00', 'thresholds': {}, 'eval': {'exact': 0.808}},
  ];

  late final client = MockClient((r) async {
    calls.add(r);
    final p = r.url.path.replaceFirst('/wp-json/my-assistant/v1', '');
    Object body = {};
    if (p == '/admin/summary') {
      body = {'members': 1284, 'pro': 96, 'trial': 41, 'new_week': 63, 'active_week': 712, 'pending_payments': payments.where((x) => x['status'] == 'pending').length, 'income_month': 18981, 'ai_today': 318, 'feedback_new': feedback.where((x) => x['status'] == 'new').length};
    } else if (p == '/admin/payments' && r.method == 'GET') {
      body = {'payments': payments.where((x) => x['status'] == r.url.queryParameters['status']).toList()};
    } else if (p.startsWith('/admin/payments/')) {
      final id = int.parse(p.split('/').last);
      final pay = payments.firstWhere((x) => x['id'] == id);
      pay['status'] = jsonDecode(r.body)['decision'] == 'approve' ? 'approved' : 'rejected';
      body = {'ok': true, 'message': 'অনুমোদন দেওয়া হলো, ${pay['email']}-এ প্রিমিয়াম চালু হলো।'};
    } else if (p == '/admin/feedback') {
      body = {'feedback': feedback.where((x) => r.url.queryParameters['status'] == 'all' || (r.url.queryParameters['status'] == 'done') == (x['status'] == 'done')).toList()};
    } else if (p == '/admin/feedback/file/70') {
      body = {'name': 'screen.png', 'mime': 'image/png', 'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='};
    } else if (p == '/admin/feedback/7/reply') {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      replies.add(j);
      messages.add({'id': 71, 'from': 'admin', 'admin': 'Boss', 'text': j['text'], 'created': _ago(Duration.zero), 'file': j['file'] == null ? null : {'name': j['file']['name'], 'mime': 'image/png', 'size': 1}});
      body = {'ok': true};
    } else if (p == '/admin/feedback/7' && r.method == 'GET') {
      body = {'feedback': feedback.first, 'messages': messages};
    } else if (p.startsWith('/admin/feedback/')) {
      feedback.firstWhere((x) => x['id'] == int.parse(p.split('/').last))['status'] = jsonDecode(r.body)['status'];
      body = {'ok': true};
    } else if (p == '/admin/members/growth') {
      body = {
        'days': [for (var i = 29; i >= 0; i--) {'day': _now.subtract(Duration(days: i)).toIso8601String().substring(0, 10), 'n': i == 0 ? 2 : (i % 7 == 0 ? 1 : 0)}],
        'months': [for (var i = 11; i >= 0; i--) {'month': '2026-${(10 - i < 1 ? 10 - i + 12 : 10 - i).toString().padLeft(2, '0')}', 'n': i == 0 ? 12 : 0}],
        'sources': [{'key': 'web', 'label': 'ওয়েবসাইট (বিকাশ)', 'n': 2}, {'key': 'bkash', 'label': 'বিকাশ — নিজে থেকে মিলেছে', 'n': 1}, {'key': 'play', 'label': 'Google Play', 'n': 0}],
        'stats': {'today_new': 2, 'month_new': 12, 'week': 3},
      };
    } else if (p == '/admin/members/print-link') {
      printLinks.add(jsonDecode(r.body) as Map<String, dynamic>);
      body = {'url': 'https://getmyassistant.app/?ma_members_print=${'a' * 48}'};
    } else if (p == '/admin/inbox') {
      body = {'members': [
        {'key': '5', 'user_id': 5, 'email': 'rakib.hasan92@gmail.com', 'name': 'রাকিব হাসান', 'picture': '', 'threads': 2, 'open': 2, 'new': 1, 'kinds': ['problem', 'idea'], 'kind_labels': ['সমস্যা', 'নতুন সুবিধা'], 'updated': _ago(const Duration(minutes: 12)), 'last': {'from': 'member', 'text': 'রাত ১০টার রিমাইন্ডার বাজেনি'}, 'thread': 7},
      ]};
    } else if (p == '/admin/inbox/5' && r.method == 'GET') {
      body = {'key': '5', 'user_id': 5, 'email': 'rakib.hasan92@gmail.com', 'name': 'রাকিব হাসান', 'picture': '', 'open': true, 'reply_to': 7,
        'threads': [{'id': 6, 'kind': 'idea', 'kind_label': 'নতুন সুবিধা', 'status': 'read', 'created': _ago(const Duration(days: 2)), 'version': '2.15.0'}, {'id': 7, 'kind': 'problem', 'kind_label': 'সমস্যা', 'status': 'read', 'created': _ago(const Duration(minutes: 12)), 'version': '2.15.0'}],
        'messages': [
          {'id': 60, 'thread': 6, 'from': 'member', 'admin': '', 'text': 'নিজের রিংটোন দেওয়া গেলে ভালো হয়', 'created': _ago(const Duration(days: 2)), 'file': null},
          for (final m in messages) {...m, 'thread': 7},
        ]};
    } else if (p == '/admin/inbox/5') {
      inboxSet.add(jsonDecode(r.body)['status'] as String);
      body = {'ok': true};
    } else if (p == '/admin/notice-stats') {
      body = {
        'push_on': true, 'phones': 9, 'phones_new_app': 4,
        'upcoming': [
          {'id': 1, 'day': _now.toIso8601String().substring(0, 10), 'time': '21:00', 'title': 'আজকের কাজের লিস্ট করেছেন?', 'audience': 'সবাই', 'how': 'push', 'how_label': 'সার্ভার থেকে পুশ', 'members': 14, 'phones': 4},
          {'id': 3, 'day': _now.toIso8601String().substring(0, 10), 'time': '18:00', 'title': 'আজ খরচ লিখেছেন?', 'audience': 'সবাই', 'how': 'phone', 'how_label': 'ফোন নিজে দেখাবে (শর্ত: সেদিন খরচ লেখা না হলে)', 'members': 14, 'phones': null},
        ],
        'groups': {'server': 'সাইটের নোটিফিকেশন', 'news': '“এখনই পাঠান”', 'reminder': 'সদস্যদের নিজের রিমাইন্ডার'},
        'days': [
          {'day': _now.toIso8601String().substring(0, 10), 'total': 17, 'failed': 2, 'server': 4, 'news': 0, 'reminder': 13},
          {'day': _now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10), 'total': 9, 'failed': 0, 'server': 0, 'news': 0, 'reminder': 9},
        ],
        'runs': {},
      };
    } else if (p == '/admin/notice-day') {
      body = {
        'day': _now.toIso8601String().substring(0, 10), 'total': 17, 'people': 3, 'avg': 5.7, 'max': 9,
        'items': [
          {'time': '08:00', 'label': 'সকালের সারাংশ', 'title': '', 'group': 'brief', 'by': 'phone', 'count': 3, 'people': 3, 'failed': 0, 'ahead': false},
          {'time': '11:11', 'label': 'সাইটের নোটিফিকেশন', 'title': 'আজ বৃহস্পতিবার', 'group': 'server', 'by': 'server', 'count': 4, 'people': 4, 'failed': 1, 'ahead': false},
          {'time': '21:00', 'label': 'রিমাইন্ডার', 'title': '', 'group': 'reminder', 'by': 'phone', 'count': 10, 'people': 2, 'failed': 0, 'ahead': true},
        ],
        'members': [
          {'user_id': 1, 'name': 'সাইফুল ইসলাম', 'email': 'saiful.islam@gmail.com', 'count': 9, 'failed': 0},
          {'user_id': 2, 'name': 'Nusrat Jahan', 'email': 'nusrat.j@gmail.com', 'count': 5, 'failed': 1},
        ],
      };
    } else if (p == '/admin/bkash') {
      body = bkash;
    } else if (p == '/admin/bkash/settings') {
      bkash['auto'] = jsonDecode(r.body)['auto'];
      body = bkash;
    } else if (p == '/admin/bkash/manual') {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      bkashManual.add(j);
      (bkash['received'] as List).insert(0, {'id': 9, 'trx': j['trx'], 'amount': j['amount'], 'sender': j['sender'], 'at': _ago(Duration.zero), 'source': 'manual', 'status': 'matched', 'status_label': 'মিলেছে — প্রিমিয়াম চালু', 'payment_id': 1});
      body = {'ok': true, 'status': 'matched', 'status_label': 'মিলেছে — প্রিমিয়াম চালু'};
    } else if (p == '/admin/members') {
      memberQueries.add(r.url.queryParameters);
      body = {'count': 3, 'words': r.url.queryParameters['joined'] == 'today' ? 'আজ যোগ দিয়েছেন' : 'সব সদস্য', 'members': [
        {'id': 1, 'name': 'সাইফুল ইসলাম', 'email': 'saiful.islam@gmail.com', 'picture': '', 'status': 'pro', 'source': 'web', 'source_label': 'ওয়েবসাইট (বিকাশ)', 'pro_until': '2027-08-12T00:00:00Z', 'joined': _ago(const Duration(days: 20)), 'last_seen': _ago(const Duration(hours: 1)), 'version': '2.14.0 play', 'note': ''},
        {'id': 2, 'name': 'Nusrat Jahan', 'email': 'nusrat.j@gmail.com', 'picture': '', 'status': 'trial', 'pro_until': _now.add(const Duration(days: 5)).toIso8601String(), 'joined': _ago(const Duration(days: 2)), 'last_seen': _ago(const Duration(hours: 3)), 'version': '2.14.0 play', 'note': ''},
        {'id': 3, 'name': '', 'email': 'sumon.dhaka@gmail.com', 'picture': '', 'status': 'free', 'pro_until': null, 'joined': _ago(const Duration(days: 30)), 'last_seen': _ago(const Duration(days: 1)), 'version': '2.14.0 direct', 'note': ''},
      ]};
    } else if (p == '/admin/finance') {
      final inc = 999 + finAdds.where((x) => x['kind'] == 'income').fold<int>(0, (a, x) => a + (x['amount'] as int));
      final exp = 1500 + 320 + finAdds.where((x) => x['kind'] == 'expense').fold<int>(0, (a, x) => a + (x['amount'] as int));
      body = {
        'month': {'month': '2026-10', 'payments': 999, 'income_other': inc - 999, 'ai': 320, 'expense_other': exp - 320, 'income': inc, 'expense': exp, 'net': inc - exp},
        'all': {'income': inc + 4950, 'expense': exp + 900, 'net': inc + 4950 - exp - 900},
        'invested': 200000, 'cash': 200000 + inc + 4950 - exp - 900,
        'months': [
          {'month': '2026-10', 'income': inc, 'expense': exp, 'net': inc - exp},
          {'month': '2026-09', 'income': 4950, 'expense': 900, 'net': 4050},
        ],
        'entries': finEntries, 'investors': investors,
        'month_lines': {
          'month': r.url.queryParameters['month'] ?? '2026-10',
          'lines': [
            for (final e in finEntries)
              if ((r.url.queryParameters['kind'] ?? '').isEmpty || e['kind'] == r.url.queryParameters['kind']) {'id': e['id'], 'date': e['on_date'], 'kind': e['kind'], 'category': e['category'], 'note': e['note'], 'amount': e['amount'], 'auto': false},
            if ((r.url.queryParameters['kind'] ?? '') != 'expense') {'id': 0, 'date': '2026-10-10', 'kind': 'income', 'category': 'প্রিমিয়াম (বার্ষিক)', 'note': 'x@gmail.com · বিকাশ BJK4', 'amount': 999, 'auto': true},
          ],
          'categories': ['সার্ভার ও হোস্টিং', 'প্রিমিয়াম (বার্ষিক)'],
          'sum': {'income': 999, 'expense': 1500},
        },
        'categories': {'income': ['বিজ্ঞাপন'], 'expense': ['সার্ভার ও হোস্টিং', 'ডোমেইন']},
      };
    } else if (p == '/admin/finance/entry') {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      finAdds.add(j);
      finEntries.insert(0, {'id': 9, 'kind': j['kind'], 'category': j['category'], 'amount': j['amount'], 'on_date': j['date'], 'note': j['note']});
      body = {'ok': true, 'id': 9};
    } else if (p == '/admin/notice-log') {
      final when = r.url.queryParameters['when'] ?? '';
      final all = [
        {'id': 9, 'source': 'plan', 'kind': 'reminder', 'label': 'রিমাইন্ডার', 'title': '', 'at': _now.add(const Duration(hours: 3)).toUtc().toIso8601String(), 'status': 'planned', 'status_label': 'আসবে', 'email': 'nusrat.j@gmail.com', 'name': 'Nusrat Jahan'},
        {'id': 8, 'source': 'push', 'kind': 'feedback', 'label': 'মতামতের উত্তর', 'title': 'আপনার মতামতের উত্তর এসেছে', 'at': _ago(const Duration(hours: 2)), 'status': 'sent', 'status_label': 'পাঠানো হয়েছে', 'email': 'saiful.islam@gmail.com', 'name': 'সাইফুল ইসলাম'},
        {'id': 7, 'source': 'push', 'kind': 'news', 'label': 'সবাইকে পাঠানো', 'title': 'নতুন সুবিধা', 'at': _ago(const Duration(days: 1)), 'status': 'no_device', 'status_label': 'ফোন যুক্ত নেই', 'email': 'sumon.dhaka@gmail.com', 'name': ''},
      ];
      final q = r.url.queryParameters['q'] ?? '';
      body = {'rows': [for (final x in all) if ((when != 'next' || x['status'] == 'planned') && (q.isEmpty || '${x['email']}'.contains(q))) x]};
    } else if (p == '/admin/notices') {
      body = {'notices': [
        {'id': '1', 'title': 'আজকের কাজের লিস্ট করেছেন?', 'body': 'চাপুন আর বলুন — কাল কী কী করবেন, লিখে রাখবো।', 'kind': 'daily', 'at_time': '21:00', 'active': '1'},
        {'id': '2', 'title': 'শুক্রবারের পরিকল্পনা', 'body': 'ছুটির দিনে কী কী করবেন?', 'kind': 'weekly', 'at_time': '20:30', 'active': '0'},
      ]};
    } else if (p == '/admin/ai/overview') {
      body = {
        'today': [{'model': 'gemini-3.1-flash-lite', 'plan': 'free', 'requests': 40, 'cost_usd': 0.012, 'per_request_usd': 0.0003, 'cache_hit': 0.5}, {'model': 'claude-haiku-5-5', 'plan': 'pro', 'requests': 4, 'cost_usd': 0.004, 'per_request_usd': 0.001, 'cache_hit': 0.8}],
        'stats': {'requests': 44, 'people': 9, 'in': 30000, 'out': 2000, 'month': 900},
        'month': [{'model': 'gemini-3.1-flash-lite', 'cost_usd': 0.41}, {'model': 'claude-haiku-5-5', 'cost_usd': 0.22}],
        'budget': {'auto': true, 'free': {'day': 0.2, 'month': 3, 'spent_day': 0.012, 'spent_month': 0.41}, 'pro': {'day': 0.09, 'month': 1.3, 'spent_day': 0.004, 'spent_month': 0.22}},
        'sources_month': {'rules': 900, 'local': 300, 'gemini': 200, 'haiku': 80, 'sonnet': 6, 'failed': 4, 'nlu_same_sure': 700, 'nlu_same': 100, 'nlu_differ_sure': 50, 'nlu_differ': 150},
        'usd_bdt': 122,
        'nlu': {'samples_30d': 420, 'error_signals_per_100': 3.4, 'weakest': [{'intent': 'reminder_edit', 'n': 30, 'bad': 9, 'ok_share': 0.7}]},
      };
    } else if (p == '/admin/ai/settings' && r.method == 'GET') {
      body = aiSettings;
    } else if (p == '/admin/ai/settings') {
      saved.add(jsonDecode(r.body) as Map<String, dynamic>);
      body = aiSettings;
    } else if (p == '/admin/family/claims') {
      body = {
        'claims': [
          {'id': 3, 'status': decisions.isEmpty ? 'review' : 'waiting', 'created': '2026-10-22T04:00:00Z', 'owner': {'id': 8, 'name': 'রাফি', 'email': 'son@gmail.com'}, 'heir': {'id': 7, 'name': 'আম্মা', 'email': 'mom@gmail.com', 'relation': 'ছেলে'}, 'note': 'গত শুক্রবার', 'file_name': 'sonod.png', 'file_mime': 'image/png', 'has_file': true, 'open_at': null, 'admin_note': ''},
        ],
      };
    } else if (p == '/admin/family/claims/3/file') {
      body = {'name': 'sonod.png', 'mime': 'image/png', 'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='};
    } else if (p == '/admin/family/claims/3') {
      decisions.add(jsonDecode(r.body) as Map<String, dynamic>);
      body = {'ok': true};
    } else if (p == '/admin/ai/selftest') {
      body = {'gemini': {'ok': true, 'ms': 900}, 'anthropic': {'ok': false, 'ms': 300, 'error': '401 invalid key'}};
    } else if (p == '/admin/nlu/review') {
      body = {'samples': reviews, 'intents': ['task_add', 'ledger_add', 'cash_add'], 'text': 'My Assistant — AI মডেল পর্যালোচনা\nবাক্য: <নাম১>কে ৫০০ টাকা দিলাম'};
    } else if (p.startsWith('/admin/nlu/review/')) {
      labels.add({'id': p.split('/').last, ...jsonDecode(r.body) as Map<String, dynamic>});
      body = {'ok': true};
    } else if (p == '/admin/nlu/models' && r.method == 'GET') {
      body = {'models': models};
    } else if (p == '/admin/nlu/models') {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final m = models.firstWhere((x) => x['version'] == j['version']);
      if (j['action'] == 'live') {
        m['status'] = 'live';
        m['rollout_pct'] = j['pct'];
      }
      body = {'ok': true, 'model': m};
    } else if (p == '/admin/login') {
      final j = jsonDecode(r.body);
      if (j['email'] != 'boss@gmail.com' || j['password'] != 'long-password-123') return http.Response('{"code":"login"}', 401);
      body = {'session': 'c' * 64, 'name': 'Boss'};
    }
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
}

/// No fingerprint hardware and no Firebase in tests.
class FakeDevice extends Device {
  bool hasFingerprint = false;
  @override
  Future<bool> canFingerprint() async => hasFingerprint;
  String? answer;
  @override
  Future<String?> verify(String reason) async => answer;
  @override
  Future<String?> pushToken() async => null;
}

Future<void> loadFonts() async {
  final hind = FontLoader('Hind');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    hind.addFont(rootBundle.load('assets/fonts/HindSiliguri-$w.ttf'));
  }
  await hind.load();
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<FakeServer> open(WidgetTester t, {bool signedIn = true}) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3.0;
  addTearDown(t.view.reset);
  await loadFonts();
  final server = FakeServer();
  // The phone's side: links open; বিকাশ মেলানো is off on this phone.
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('my_assistant/open'), (c) async {
    server.opened.add('${(c.arguments as Map)['url']}');
    return true;
  });
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('my_assistant/bkash'), (c) async => switch (c.method) {
        'status' || 'flush' => {'on': false, 'permission': false, 'last': null, 'queued': 0},
        'scan' => <Object>[],
        _ => true,
      });
  final store = MemorySession()..value = signedIn ? 'c' * 64 : null;
  await t.pumpWidget(AdminApp(api: Api(client: server.client, store: store, base: 'https://getmyassistant.app'), device: FakeDevice()));
  await settle(t);
  return server;
}

final shots = Platform.environment['SHOTS'] == '1';
Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

void main() {
  testWidgets('summary, then approve a payment; only the session goes to the server', (t) async {
    final server = await open(t);
    expect(find.text('১,২৮৪'), findsOneWidget);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsOneWidget);
    await shot(t, 'dashboard');
    await t.tap(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'));
    await settle(t);
    expect(find.text('BJK4Q9X2PL'), findsOneWidget);
    await shot(t, 'payments');
    await t.tap(find.widgetWithText(FilledButton, 'অনুমোদন').first);
    await settle(t);
    expect(find.text('পেমেন্ট মিলেছে?'), findsOneWidget);
    await shot(t, 'approve');
    await t.tap(find.text('মিলেছে — প্রিমিয়াম দিন'));
    await settle(t);
    expect(server.payments.first['status'], 'approved');
    final decided = server.calls.firstWhere((r) => r.url.path.endsWith('/admin/payments/1'));
    expect(decided.headers['authorization'], 'Bearer ${'c' * 64}');
    expect(find.text('BJK4Q9X2PL'), findsNothing);
  });

  testWidgets('members and notifications', (t) async {
    await open(t);
    await t.tap(find.text('সদস্য').last);
    await settle(t);
    expect(find.text('সাইফুল ইসলাম'), findsOneWidget);
    await shot(t, 'members');
    await t.tap(find.text('সাইফুল ইসলাম'));
    await settle(t);
    expect(find.text('+১ বছর'), findsOneWidget);
    await t.tapAt(const Offset(20, 40));
    await settle(t);
    await t.tap(find.text('নোটিফিকেশন').last);
    await settle(t);
    expect(find.text('আজকের কাজের লিস্ট করেছেন?'), findsOneWidget);
    await shot(t, 'notices');
    // কী কখন যাচ্ছে, দিনে কতটি (no list of who got what).
    await t.tap(find.byKey(const Key('notice-log')));
    await settle(t);
    expect(find.text('সামনের ৭ দিন'), findsOneWidget);
    expect(find.text('আজ খরচ লিখেছেন?'), findsOneWidget);
    expect(find.textContaining('৪টি ফোনে পুশ'), findsOneWidget);
    expect(find.textContaining('পৌঁছায়নি ২'), findsOneWidget);
    expect(find.textContaining('rakib'), findsNothing);
    await shot(t, 'notice_stats');
    // One day: what, when; and how many each member gets.
    await t.tap(find.byKey(const Key('notice-today')));
    await settle(t);
    expect(find.text('আজ বৃহস্পতিবার'), findsOneWidget);
    expect(find.text('কে দিনে কতগুলো পাচ্ছে'), findsOneWidget);
    await t.scrollUntilVisible(find.text('৯টি'), 200);
    expect(find.text('৯টি'), findsOneWidget);
    await shot(t, 'notice_day');
  });

  testWidgets('members: by join date and source, new per day, PDF in the browser', (t) async {
    final server = await open(t);
    await t.tap(find.text('সদস্য').last);
    await settle(t);
    expect(find.byKey(const Key('growth')), findsOneWidget);
    expect(find.textContaining('এ মাসে ১২'), findsOneWidget);
    expect(find.textContaining('ওয়েবসাইট (বিকাশ)'), findsWidgets);
    await shot(t, 'members_growth');
    await t.tap(find.byKey(const Key('joined-today')));
    await settle(t);
    expect(server.memberQueries.last['joined'], 'today');
    expect(find.textContaining('আজ যোগ দিয়েছেন'), findsOneWidget);
    await t.tap(find.text('মাসিক'));
    await settle(t);
    expect(find.text('অক্টো'), findsWidgets);
    await t.tap(find.byKey(const Key('members-pdf')));
    await settle(t);
    expect(server.printLinks.single['joined'], 'today');
    expect(server.opened.single, startsWith('https://getmyassistant.app/?ma_members_print='));
  });

  testWidgets('হিসাব: income, expense, profit, investors; write a cost', (t) async {
    final server = await open(t);
    await t.scrollUntilVisible(find.byKey(const Key('open-finance')), 200);
    await t.tap(find.byKey(const Key('open-finance')));
    await settle(t);
    expect(find.text('এ মাসে আয়'), findsOneWidget);
    expect(find.text('করিম চৌধুরী'), findsOneWidget);
    expect(find.text('৳৯৯৯'), findsOneWidget);
    await shot(t, 'finance');
    await t.tap(find.byKey(const Key('fin-add')));
    await settle(t);
    await t.tap(find.text('ডোমেইন'));
    await t.enterText(find.byKey(const Key('fin-amount')), '1200');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(server.finAdds.single, containsPair('category', 'ডোমেইন'));
    expect(server.finAdds.single['amount'], 1200);
    expect(find.text('ডোমেইন'), findsOneWidget);
  });

  testWidgets('feedback: one inbox per member, both conversations, answer with text', (t) async {
    final server = await open(t);
    await t.tap(find.text('মতামত').last);
    await settle(t);
    expect(find.text('রাকিব হাসান'), findsOneWidget);
    expect(find.textContaining('২টা কথোপকথন'), findsOneWidget);
    await shot(t, 'feedback');
    await t.tap(find.text('রাকিব হাসান'));
    await settle(t);
    expect(find.text('নিজের রিংটোন দেওয়া গেলে ভালো হয়'), findsOneWidget);
    expect(find.text('রাত ১০টার রিমাইন্ডার বাজেনি'), findsOneWidget);
    expect(server.calls.any((r) => r.url.path.endsWith('/admin/feedback/file/70')), isTrue, reason: 'the screenshot is fetched');
    await t.enterText(find.byKey(const Key('admin-reply')), 'ফোনের ব্যাটারি সেটিং দেখুন');
    await t.tap(find.byKey(const Key('admin-send')));
    await settle(t);
    expect(server.replies.single['text'], 'ফোনের ব্যাটারি সেটিং দেখুন');
    expect(server.calls.any((r) => r.url.path.endsWith('/admin/feedback/7/reply')), isTrue, reason: 'to the newest open conversation');
    await shot(t, 'thread');
  });

  testWidgets('বিকাশ মেলানো: the card, auto approval, a pasted message (only four fields go)', (t) async {
    final server = await open(t);
    await t.tap(find.text('পেমেন্ট').last);
    await settle(t);
    expect(find.byKey(const Key('bkash-card')), findsOneWidget);
    await t.tap(find.byKey(const Key('bkash-card')));
    await settle(t);
    await settle(t);
    await shot(t, 'bkash');
    await t.scrollUntilVisible(find.text('টাকা কম'), 200);
    expect(find.text('৳৯৯৯ · 9A7KX2PQ1M'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('bkash-auto')), -200);
    await t.tap(find.byKey(const Key('bkash-auto')));
    await settle(t);
    expect(server.bkash['auto'], false);
    await t.scrollUntilVisible(find.byKey(const Key('bkash-paste-open')), 100);
    await t.tap(find.byKey(const Key('bkash-paste-open')));
    await settle(t);
    await settle(t);
    await t.enterText(find.byKey(const Key('bkash-paste')), 'You have received Tk 99.00 from 01811111111. Fee Tk 0.00. Balance Tk 12,345.00. TrxID ABCD123456 at 27/10/2026 15:02');
    await t.tap(find.text('মেলান'));
    await settle(t);
    final sent = server.bkashManual.single;
    expect(sent.keys.toSet(), {'trx', 'amount', 'sender', 'at'});
    expect(sent['trx'], 'ABCD123456');
    expect(sent['amount'], 99);
    expect(jsonEncode(sent).contains('12,345'), isFalse, reason: 'no balance');
  });

  test('a bKash message is read the same as on the server', () {
    final p = parseBkash('You have received Tk 999.00 from 01712345678. Ref 12. Fee Tk 0.00. Balance Tk 5,210.50. TrxID 9A7KX2PQ1M at 27/10/2026 15:02')!;
    expect(p['trx'], '9A7KX2PQ1M');
    expect(p['amount'], 999);
    expect(p['sender'], '01712345678');
    expect(p['at'], '2026-10-27T09:02:00.000Z');
    final b = parseBkash('আপনি ০১৮১২৩৪৫৬৭৮ থেকে ৯৯.০০ টাকা পেয়েছেন। TrxID BJR4XYZ123 সময় ২৭/১০/২০২৬ ১০:১৫')!;
    expect(b['amount'], 99);
    expect(b['sender'], '01812345678');
    expect(parseBkash('Cash In Tk 500.00 from 01712345678 successful. TrxID 8J7K6L5M4N'), isNull);
    expect(parseBkash('Send Money Tk 50.00 to 01712345678 successful. TrxID 7J7K6L5M4N'), isNull);
  });

  testWidgets('AI ও বোঝা: cost in taka, sources, review, a model to 10%, settings and the self-test', (t) async {
    final server = await open(t);
    await t.tap(find.text('AI').last);
    await settle(t);
    expect(find.text('৳১.৯৫'), findsOneWidget); // today: $0.016 × 122
    expect(find.textContaining('AI প্রশ্ন ৪৪'), findsOneWidget, reason: 'the same as the site\'s AI খরচ page');
    await shot(t, 'ai-summary');
    final sum = find.descendant(of: find.byType(AiSummary), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.textContaining('claude-haiku-5-5 · pro'), 300, scrollable: sum);
    expect(find.textContaining('claude-haiku-5-5 · pro'), findsWidgets);
    await t.scrollUntilVisible(find.textContaining('ফোনে সমাধান ৮১%'), 300, scrollable: sum);
    expect(find.textContaining('ফোনে সমাধান ৮১%'), findsOneWidget); // 1200 of 1490
    await t.scrollUntilVisible(find.textContaining('মিল ৮০%'), 300, scrollable: sum);
    expect(find.textContaining('মিল ৮০%'), findsOneWidget);
    await t.scrollUntilVisible(find.text('reminder_edit'), 300, scrollable: sum);
    expect(find.text('reminder_edit'), findsOneWidget);
    await t.tap(find.text('পর্যালোচনা'));
    await settle(t);
    expect(find.text('<নাম১>কে ৫০০ টাকা দিলাম'), findsOneWidget);
    await shot(t, 'ai-review');
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    await t.tap(find.byKey(const Key('review-copy')));
    await settle(t);
    expect(copied, contains('বাক্য: <নাম১>কে ৫০০ টাকা দিলাম'));
    expect(find.textContaining('সব কপি হয়েছে'), findsOneWidget);
    await t.tap(find.text('ক্লাউড ঠিক'));
    await settle(t);
    expect(server.labels.single['intents'], ['ledger_add']);
    expect(server.labels.single['pick'], 'cloud');
    expect(find.text('দেখার মতো কিছু নেই'), findsOneWidget);
    await t.tap(find.text('মডেল'));
    await settle(t);
    expect(find.text('m2'), findsOneWidget);
    await t.tap(find.text('চালু করুন'));
    await settle(t);
    expect(server.models.single['status'], 'live');
    expect(server.models.single['rollout_pct'], 10);
    await t.tap(find.text('সেটিংস'));
    await settle(t);
    await shot(t, 'ai-settings');
    await t.tap(find.text('চালু'));
    final list = find.descendant(of: find.byType(AiSettings), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('রাখুন'), 300, scrollable: list);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect((server.saved.single['nlu'] as Map)['mode'], 'on');
    expect(server.saved.single['budgets_auto'], true);
    expect(server.saved.single['ai_per_user'], 30, reason: 'owner: the settings page\'s fields are here too');
    expect(((server.saved.single['prices'] as Map)['claude-haiku-5-5'] as Map)['out'], 5);
    expect((server.saved.single['keys'] as Map)['anthropic_key'], '', reason: 'an empty key field changes nothing');
    await t.pump(const Duration(seconds: 6)); // the "রাখা হয়েছে" note goes away
    await settle(t);
    await t.scrollUntilVisible(find.text('Gemini আর Claude পরীক্ষা'), 300, scrollable: list);
    await t.tap(find.text('Gemini আর Claude পরীক্ষা'));
    await settle(t);
    await t.scrollUntilVisible(find.textContaining('Gemini: কাজ করছে'), 300, scrollable: list);
    expect(find.textContaining('Gemini: কাজ করছে'), findsOneWidget);
    expect(find.textContaining('Claude: কাজ করছে না 401'), findsOneWidget);
    await t.scrollUntilVisible(find.text('k' * 48), 300, scrollable: list);
    expect(find.text('k' * 48), findsOneWidget, reason: 'the retraining key, as on the settings page');
  });

  testWidgets('signed out: email and password, then in', (t) async {
    final server = await open(t, signedIn: false);
    expect(find.text('লগইন'), findsOneWidget);
    await shot(t, 'signin');
    await t.enterText(find.byKey(const Key('email')), 'boss@gmail.com');
    await t.enterText(find.byKey(const Key('password')), 'wrong-one');
    await t.tap(find.byKey(const Key('sign-in')));
    await settle(t);
    expect(find.textContaining('মেলেনি'), findsOneWidget);
    await t.enterText(find.byKey(const Key('password')), 'long-password-123');
    await t.tap(find.byKey(const Key('sign-in')));
    await settle(t);
    await settle(t);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsOneWidget);
    expect(server.calls.where((r) => r.url.path.endsWith('/admin/login')).length, 2);
  });

  testWidgets('fingerprint lock when it is on', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    final server = FakeServer();
    final store = MemorySession()..value = 'c' * 64;
    store.flags['fingerprint'] = true;
    final device = FakeDevice()..answer = 'ফোনে কোনো আঙুলের ছাপ রাখা নেই';
    await t.pumpWidget(AdminApp(api: Api(client: server.client, store: store, base: 'https://x'), device: device));
    await settle(t);
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    // The phone said why it could not: shown under the button, still locked.
    expect(find.byKey(const Key('unlock-problem')), findsOneWidget);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsNothing);
    device.answer = null;
    await t.tap(find.byKey(const Key('unlock')));
    await settle(t);
    expect(find.text('২টা পেমেন্ট দেখার অপেক্ষায়'), findsOneWidget);
  });

  test('only the session is kept; logout forgets it and the fingerprint', () async {
    final server = FakeServer();
    final store = MemorySession();
    final api = Api(client: server.client, store: store, base: 'https://x');
    await expectLater(api.login('boss@gmail.com', 'nope'), throwsA(isA<ApiError>()));
    expect(store.value, isNull);
    expect(await api.login('boss@gmail.com', 'long-password-123'), 'Boss');
    expect(store.value, 'c' * 64);
    await api.setFingerprint(true);
    expect(await api.fingerprintOn(), isTrue);
    await api.logout();
    expect(store.value, isNull);
    expect(await api.fingerprintOn(), isFalse);
  });

  testWidgets('উত্তরাধিকার: the reported death with the certificate; approve with a note (the same as on the site)', (t) async {
    final server = await open(t);
    await t.tap(find.text('সদস্য').last);
    await settle(t);
    await t.tap(find.byKey(const Key('heirs-open')));
    await settle(t);
    expect(find.text('রাফি'), findsOneWidget);
    expect(find.textContaining('সম্পর্ক: ছেলে'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget, reason: 'the certificate is shown');
    await t.tap(find.byKey(const Key('claim-approve-3')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'সনদ মিলেছে');
    await t.tap(find.byKey(const Key('claim-confirm')));
    await settle(t);
    expect(server.decisions.single, {'action': 'approve', 'note': 'সনদ মিলেছে'});
    expect(find.text('১৪ দিনের অপেক্ষা'), findsOneWidget);
  });
}
