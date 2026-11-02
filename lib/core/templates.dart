// Message templates: every WhatsApp message the app writes can be reworded
// by an admin. A template is plain text with {fields}. A line whose fields
// all came out empty is left out, so optional lines (operator, pack, TrxID,
// the signature) disappear on their own.

class MsgTemplate {
  const MsgTemplate(this.key, this.to, this.title, this.fields, this.def);
  final String key;

  /// 'agent' or 'customer'.
  final String to;
  final String title;

  /// (field, what it is).
  final List<(String, String)> fields;
  final String def;
}

const _replyRule = 'উত্তরের_নিয়ম';

const msgTemplates = <MsgTemplate>[
  MsgTemplate('agent_send', 'agent', 'নতুন বিকাশ/নগদ/রকেট/ব্যাংক', [
    ('নং', 'লেনদেন নম্বর, যেমন 26110001'),
    ('মাধ্যম', 'বিকাশ, নগদ, রকেট বা ব্যাংক'),
    ('নম্বর', 'যে নম্বরে যাবে'),
    ('টাকা', 'এজেন্ট যত টাকা পাঠাবেন'),
    ('খরচ', 'খরচসহ হলে মূল টাকার কথা (না হলে খালি)'),
    ('ধরন', 'সেন্ড মানি / ক্যাশ আউট'),
    (_replyRule, 'কীভাবে রিপ্লাই দিতে হবে (নিচের টেমপ্লেট)'),
  ], 'নতুন {মাধ্যম} — #{নং}\nনম্বর: {নম্বর}\nটাকা: {টাকা}{খরচ}\nধরন: {ধরন}\n{উত্তরের_নিয়ম}'),
  MsgTemplate('agent_topup', 'agent', 'নতুন রিচার্জ/এমবি', [
    ('নং', 'লেনদেন নম্বর'),
    ('ধরন', 'রিচার্জ বা এমবি'),
    ('নম্বর', 'যে নম্বরে যাবে'),
    ('অপারেটর', 'গ্রামীণফোন, রবি…'),
    ('প্যাক', 'এমবি প্যাক (না থাকলে খালি)'),
    ('টাকা', 'টাকার পরিমাণ'),
    (_replyRule, 'কীভাবে রিপ্লাই দিতে হবে'),
  ], 'নতুন {ধরন} — #{নং}\nনম্বর: {নম্বর}\nঅপারেটর: {অপারেটর}\nপ্যাক: {প্যাক}\nটাকা: {টাকা}\n{উত্তরের_নিয়ম}'),
  MsgTemplate('agent_reply_rule', 'agent', 'রিপ্লাইয়ের নিয়ম (উপরের মেসেজের ভেতরে বসে)', [
    ('নং', 'লেনদেন নম্বর'),
    ('টাকা', 'টাকার পরিমাণ'),
  ], 'পাঠানোর পর এই মেসেজে রিপ্লাই দিন — আগে লেনদেন নং, তারপর টাকা-যে নম্বর থেকে পাঠালেন তার শেষ ৩ সংখ্যা।\nযেমন: {নং} {টাকা}-XXX (TrxID থাকলে সেটাও)'),
  MsgTemplate('agent_change', 'agent', 'লেনদেন সংশোধন', [
    ('নং', 'লেনদেন নম্বর'),
    ('বিস্তারিত', 'নতুন মেসেজের নম্বর, টাকা ইত্যাদি অংশ'),
  ], 'সংশোধন — #{নং}\n{বিস্তারিত}'),
  MsgTemplate('agent_cancel', 'agent', 'লেনদেন বাতিল', [
    ('নং', 'লেনদেন নম্বর'),
    ('নম্বর', 'যে নম্বরে যাওয়ার কথা ছিল'),
    ('টাকা', 'টাকার পরিমাণ'),
  ], 'বাতিল — #{নং}\nনম্বর: {নম্বর}\nটাকা: {টাকা}\nএটা পাঠাবেন না।'),
  MsgTemplate('agent_day', 'agent', 'এজেন্টকে দিনের হিসাব', [
    ('তারিখ', 'দিনের তারিখ'),
    ('তালিকা', 'দিনের সব লেনদেন, এক লাইনে একটা'),
    ('মোট', 'দিনের মোট টাকা'),
    ('সংখ্যা', 'কয়টা লেনদেন'),
    ('পাওনা', 'এজেন্টের মোট পাওনা'),
  ], 'হিসাব — {তারিখ}\n{তালিকা}\nআজ মোট: {মোট} টাকা ({সংখ্যা}টা)\nআপনার মোট পাওনা: {পাওনা} টাকা'),
  MsgTemplate('cust_receipt', 'customer', 'টাকা পৌঁছানোর রসিদ', [
    ('নাম', 'গ্রাহকের নাম'),
    ('খবর', '"আপনার টাকা পৌঁছেছে।" বা "আপনার রিচার্জ হয়ে গেছে।"'),
    ('প্রাপক', 'প্রাপকের নাম ও নম্বর'),
    ('মাধ্যম', 'বিকাশ, রিচার্জ · রবি…'),
    ('প্যাক', 'এমবি প্যাক (না থাকলে খালি)'),
    ('টাকা', 'টাকার পরিমাণ'),
    ('TrxID', 'TrxID (না থাকলে খালি)'),
    ('পিন', 'যে নম্বর থেকে গেছে তার শেষ কয়েক সংখ্যা (না দিলে খালি)'),
    ('রিয়াল', 'রিয়াল, নগদ দিলে "(পরিশোধ)" সহ'),
    ('বকেয়া', 'গ্রাহকের মোট বকেয়া (বকেয়া না থাকলে খালি)'),
    ('স্বাক্ষর', 'মালিকের নাম'),
  ], 'আসসালামু আলাইকুম {নাম},\n{খবর}\nপ্রাপক: {প্রাপক} ({মাধ্যম})\nপ্যাক: {প্যাক}\nটাকা: {টাকা}\nTrxID: {TrxID}\nপিন: {পিন}\nরিয়াল: {রিয়াল}\nআপনার মোট বকেয়া: {বকেয়া}\n— {স্বাক্ষর}'),
  MsgTemplate('cust_deposit', 'customer', 'রিয়াল জমার রসিদ', [
    ('নাম', 'গ্রাহকের নাম'),
    ('রিয়াল', 'যত রিয়াল জমা'),
    ('বকেয়া', 'এখন বকেয়া (বকেয়া না থাকলে খালি)'),
    ('স্বাক্ষর', 'মালিকের নাম'),
  ], 'আসসালামু আলাইকুম {নাম},\n{রিয়াল} রিয়াল জমা পেয়েছি, ধন্যবাদ।\nএখন বকেয়া: {বকেয়া}\n— {স্বাক্ষর}'),
  MsgTemplate('cust_due', 'customer', 'বকেয়ার তাগাদা', [
    ('নাম', 'গ্রাহকের নাম'),
    ('বকেয়া', 'বকেয়া রিয়াল'),
    ('স্বাক্ষর', 'মালিকের নাম'),
  ], 'আসসালামু আলাইকুম {নাম},\nআপনার কাছে {বকেয়া} রিয়াল বকেয়া আছে। সুবিধামতো দিয়ে দিলে উপকার হয়।\nধন্যবাদ।\n— {স্বাক্ষর}'),
  MsgTemplate('cust_statement', 'customer', 'গ্রাহকের পুরো হিসাব', [
    ('নাম', 'গ্রাহকের নাম'),
    ('তালিকা', 'সব লেনদেন ও জমা, এক লাইনে একটা'),
    ('বকেয়া', 'মোট বকেয়া (বকেয়া না থাকলে খালি)'),
    ('স্বাক্ষর', 'মালিকের নাম'),
  ], '{নাম} — হিসাব\n{তালিকা}\nমোট বকেয়া: {বকেয়া}\n— {স্বাক্ষর}'),
];

MsgTemplate templateOf(String key) => msgTemplates.firstWhere((t) => t.key == key);

final _field = RegExp(r'\{([^{}\n]+)\}');

/// Fills [text] with [values]. Unknown fields are left as typed; a line
/// whose known fields are all empty is dropped.
String fillTemplate(String text, Map<String, String> given) {
  // {বাকি} from wording saved before the word became বকেয়া still works.
  final values = {...given};
  if (values.containsKey('বকেয়া')) values.putIfAbsent('বাকি', () => values['বকেয়া']!);
  final out = <String>[];
  for (final line in text.split('\n')) {
    final found = _field.allMatches(line).map((m) => m[1]!).where(values.containsKey).toList();
    if (found.isNotEmpty && found.every((f) => values[f]!.trim().isEmpty)) continue;
    out.add(line.replaceAllMapped(_field, (m) => values.containsKey(m[1]) ? values[m[1]]! : m[0]!));
  }
  return out.join('\n').trim();
}

/// Fields used in [text] that the template does not know.
List<String> unknownFields(MsgTemplate t, String text) {
  final known = {for (final f in t.fields) f.$1, if (t.fields.any((f) => f.$1 == 'বকেয়া')) 'বাকি'};
  return {for (final m in _field.allMatches(text)) m[1]!}.where((f) => !known.contains(f)).toList();
}
