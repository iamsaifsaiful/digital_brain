/// Prompt suggestions while the user types: from a word or two ("বিদ্যুৎ
/// বিল") the things that can be done with it, as full sentences the app
/// understands. A tap puts the sentence in the box to change and send.
library;

import '../models/models.dart';
import 'app_map.dart';
import 'ledger.dart';
import 'parser.dart' show normalize, words, mentionsSecret;
import 'phrases.dart';

/// A kind of thing typed, with the sentences that fit it. `{x}` is what was typed.
class _Topic {
  const _Topic(this.keys, this.prompts);
  final List<String> keys;
  final List<String> prompts;
}

const _topics = [
  // Bills, rent, fees.
  _Topic(['বিল', 'ভাড়া', 'ফি', 'রিচার্জ', 'ইন্টারনেট', 'গ্যাস', 'পানির', 'বিদ্যুৎ', 'বিদ্যুত', 'কারেন্ট', 'ডিশ', 'টিউশন', 'কিস্তি', 'ইএমআই', 'বেতন দেওয়া', 'চাঁদা'], [
    'প্রতি মাসের ১০ তারিখে {x} দেওয়ার কথা মনে করিয়ে দিও',
    'আজ {x} বাবদ ১০০০ টাকা খরচ হলো',
    'এ মাসে কত খরচ হলো?',
    '{x} দেওয়া কাজের তালিকায় রাখো',
  ]),
  // Medicine.
  _Topic(['ওষুধ', 'ঔষধ', 'ট্যাবলেট', 'ক্যাপসুল', 'সিরাপ', 'নাপা', 'প্যারাসিটামল', 'ইনসুলিন', 'ভিটামিন'], [
    'প্রতিদিন সকাল ৯টায় {x} খাওয়ার কথা মনে করিয়ে দিও',
    'প্রতিদিন রাত ১০টায় {x} খাওয়ার কথা মনে করিয়ে দিও',
    '{x} কেনা কাজের তালিকায় রাখো',
  ]),
  // Health readings.
  _Topic(['প্রেশার', 'রক্তচাপ', 'বিপি'], ['আজ প্রেশার ১২০/৮০', 'আমার শেষ প্রেশার কত?']),
  _Topic(['সুগার', 'ডায়াবেটিস', 'ডায়াবেটিস'], ['আজ সুগার ৬.৫', 'আমার শেষ সুগার কত?']),
  _Topic(['ওজন'], ['আজ ওজন ৬৫ কেজি', 'আমার ওজন কত?']),
  // Shopping.
  _Topic(['বাজার', 'চাল', 'ডাল', 'তেল', 'ডিম', 'পেঁয়াজ', 'পিয়াজ', 'মাছ', 'মাংস', 'দুধ', 'সবজি', 'চিনি', 'লবণ', 'আটা', 'সাবান', 'কেনা'], [
    'বাজারের লিস্টে {x} রাখো',
    'আজ {x} কিনতে ৫০০ টাকা খরচ হলো',
    'বাজারের লিস্ট দেখাও',
  ]),
  // Meetings and appointments.
  _Topic(['মিটিং', 'ডাক্তার', 'অফিস', 'ক্লাস', 'পরীক্ষা', 'দাওয়াত', 'বিয়ে', 'অনুষ্ঠান', 'ফ্লাইট', 'ট্রেন', 'বাস', 'ইন্টারভিউ', 'অ্যাপয়েন্টমেন্ট', 'সাক্ষাৎ'], [
    'কাল সকাল ১০টায় {x} আছে, মনে করিয়ে দিও',
    'কাল সকাল ১০টায় {x}, ১ ঘণ্টা আগে মনে করিয়ে দিও',
    '{x} কাজের তালিকায় রাখো',
  ]),
  // Yearly days.
  _Topic(['জন্মদিন', 'বিবাহবার্ষিকী', 'বিবাহ বার্ষিকী', 'মৃত্যুবার্ষিকী'], ['{x} ১২ মার্চ', 'কার কার জন্মদিন সামনে?']),
  // Alarms.
  _Topic(['এলার্ম', 'অ্যালার্ম', 'ঘুম', 'alarm'], ['কাল সকাল ৬টায় এলার্ম দাও', 'প্রতিদিন সকাল ৬টায় এলার্ম দাও', '৩০ মিনিট পর এলার্ম দাও']),
  // Money in.
  _Topic(['বেতন', 'স্যালারি', 'আয়', 'ইনকাম'], ['আজ বেতন ৩০০০০ টাকা পেলাম', 'এ মাসে মোট কত আয় হলো?']),
  _Topic(['বিক্রি', 'বেচা', 'সেল'], ['আজ দোকানে ৫০০০ টাকা বিক্রি হলো', 'এ মাসে মোট কত আয় হলো?', 'দোকান খোলো']),
  _Topic(['খরচ', 'ব্যয়'], ['আজ বাজারে ৫০০ টাকা খরচ', 'এ মাসে কত খরচ হলো?', 'মাসের রিপোর্ট খোলো']),
  // Loans.
  _Topic(['ধার', 'পাওনা', 'দেনা', 'বাকি', 'লোন', 'ঋণ'], ['আমার মোট পাওনা কত?', 'আমি কাকে কত দেব?', 'সব লেনদেন খোলো']),
  // Papers.
  _Topic(['এনআইডি', 'nid', 'পাসপোর্ট', 'লাইসেন্স', 'সার্টিফিকেট', 'দলিল', 'জন্ম নিবন্ধন', 'টিন', 'কাগজ', 'ডকুমেন্ট'], ['ডকুমেন্টস খোলো', 'কাগজের মেয়াদ খোলো']),
  // Lists and plans.
  _Topic(['কাজ', 'টুডু', 'লিস্ট', 'তালিকা'], ['আজকের কাজের লিস্ট দাও', 'কাজের তালিকা খোলো']),
  _Topic(['পিডিএফ', 'pdf', 'রিপোর্ট'], ['পিডিএফ দাও', 'মাসের রিপোর্ট খোলো']),
];

/// Typed words that already make a request: no suggestions then.
const _verbs = [
  'দাও', 'দিও', 'দেন', 'রাখো', 'রাখেন', 'রাখুন', 'করো', 'করেন', 'করুন', 'খোলো', 'খুলুন', 'দেখাও', 'দিলাম', 'নিলাম', 'পেলাম', 'হলো', 'হল', 'হয়েছে', 'কত', 'কবে', 'কখন', 'কী', 'কি', '?',
];

bool _has(String typed, String key) {
  final k = normalize(key);
  if (k.isEmpty) return false;
  if (k.contains(' ')) return typed.contains(k);
  // Short keys ("ফি", "চাল") only as the word itself or with a case ending.
  if (k.length <= 3) return words(typed).any((w) => w == k || w == '$kের' || w == '$kর' || w == '$kে' || w == '$kএর');
  return words(typed).any((w) => w.startsWith(k));
}

/// Up to [max] full sentences for what is being typed (empty when the box
/// is empty, too long, or already a request).
List<String> suggestPrompts(String typed, AppData d, {int max = 5}) {
  final raw = typed.trim().replaceAll(RegExp(r'[।,.!]+$'), '');
  final t = normalize(raw);
  final ws = words(t);
  if (ws.isEmpty || ws.length > 4 || raw.length < 2) return const [];
  if (raw.endsWith('?') || _verbs.any((v) => ws.contains(normalize(v)))) return const [];
  if (mentionsSecret(raw)) return const [];
  final out = <String>[];
  void add(String s) {
    if (!out.contains(s) && s.trim() != raw) out.add(s);
  }

  // A person the user knows: money, a call, a message.
  final people = {
    for (final c in d.contacts) c.name.trim(),
    for (final p in balances(d.ledger)) p.name.trim(),
  }..removeWhere((n) => n.isEmpty);
  final last = ws.last;
  for (final n in people) {
    final nn = normalize(n);
    if (last.length >= 2 && (nn.startsWith(last) || nn == t || nn.startsWith(t))) {
      add('${toPerson(n)} ৫০০ টাকা ধার দিলাম');
      add('${possessive(n)} কাছে কত পাবো?');
      add('${toPerson(n)} ফোন দাও');
      add('${toPerson(n)} মেসেজ দাও যে ');
      break;
    }
  }

  // Things already kept with this word.
  if (last.length >= 3) {
    for (final r in d.reminders) {
      if (normalize(r.title).contains(t)) {
        add('${possessive(r.title)} রিমাইন্ডার কবে?');
        break;
      }
    }
    for (final task in d.tasks) {
      if (!task.done && normalize(task.title).contains(t)) {
        add('${task.title} হয়ে গেছে');
        break;
      }
    }
  }

  // What kind of thing it is.
  for (final topic in _topics) {
    if (topic.keys.any((k) => _has(t, k))) {
      for (final p in topic.prompts) {
        add(p.replaceAll('{x}', raw));
      }
    }
  }

  // A part of the app.
  final place = placeMentioned(t);
  if (place != null && place.id != 'home') add('${place.title} খোলো');

  // Anything else: the common things to do with it.
  if (out.length < 3) {
    add('কাল সকাল ১০টায় $raw মনে করিয়ে দিও');
    add('$raw কাজের তালিকায় রাখো');
    add('$raw নোট করে রাখো');
  }
  return out.take(max).toList();
}
