// What a person said, in the app's standard Bengali — before anything is
// understood: regional forms ("আইজকা", "কাইল", "কামডা", "কইরা ফালাইছি",
// "যামু", "মনে করায়া দিও") and Banglish typed in English letters
// ("kal doctor er kache jabo", "bazar kora hoye gese"). Only words with one
// clear meaning are changed; names and anything else stay as said.
import 'bn.dart';

/// Regional and spoken forms → standard (whole words only).
const _dialect = {
  'আইজ': 'আজ', 'আইজকা': 'আজকে', 'আইজকে': 'আজকে', 'আজকা': 'আজকে',
  'কাইল': 'কাল', 'কাইলকা': 'কালকে', 'কাইলকে': 'কালকে', 'কালকা': 'কালকে',
  'কাম': 'কাজ', 'কামডা': 'কাজটা', 'কামটা': 'কাজটা', 'কামের': 'কাজের', 'কামগুলা': 'কাজগুলো', 'কামগুলান': 'কাজগুলো', 'কাম গুলান': 'কাজগুলো', 'কামগুলো': 'কাজগুলো',
  'গুলান': 'গুলো', 'গুলা': 'গুলো',
  'কইরা': 'করে', 'কইরে': 'করে', 'ফালাইছি': 'ফেলেছি', 'ফালাইসি': 'ফেলেছি', 'কইরাছি': 'করেছি',
  'যামু': 'যাব', 'যাইমু': 'যাব', 'করমু': 'করব', 'দিমু': 'দেব', 'নিমু': 'নেব', 'কিনমু': 'কিনব', 'খামু': 'খাব',
  'লেইখা': 'লিখে', 'রাইখা': 'রেখে', 'দেহাইতে': 'দেখাতে', 'দেহাও': 'দেখাও', 'হইবো': 'হবে', 'হইব': 'হবে', 'লাগবো': 'লাগবে',
  'করায়া': 'করিয়ে', 'করাইয়া': 'করিয়ে', 'করায়ে': 'করিয়ে', 'মনে করাইও': 'মনে করিও', 'দেও': 'দাও',
  'হইছে': 'হয়েছে', 'হইসে': 'হয়েছে', 'গেছে গা': 'গেছে',
};

/// Banglish words → Bengali, used only when most of the message is in
/// English letters (an English sentence stays English).
const _banglish = {
  'aj': 'আজ', 'aaj': 'আজ', 'ajke': 'আজকে', 'kal': 'কাল', 'kalke': 'কালকে', 'porshu': 'পরশু',
  'kaj': 'কাজ', 'kajer': 'কাজের', 'kajgulo': 'কাজগুলো', 'kam': 'কাজ', 'list': 'লিস্ট', 'talika': 'তালিকা', 'todo': 'টুডু', 'task': 'কাজ',
  'dao': 'দাও', 'dekhao': 'দেখাও', 'dekhan': 'দেখান', 'bolo': 'বলো', 'chai': 'চাই',
  'ki': 'কি', 'koto': 'কত', 'koyta': 'কয়টা', 'ache': 'আছে', 'ase': 'আছে', 'baki': 'বাকি', 'amar': 'আমার', 'ta': 'টা', 'er': 'এর', 'gulo': 'গুলো',
  'hobe': 'হবে', 'jabo': 'যাব', 'korbo': 'করব', 'kinbo': 'কিনব', 'dibo': 'দেব', 'debo': 'দেব', 'kinte': 'কিনতে', 'dite': 'দিতে', 'nite': 'নিতে', 'jete': 'যেতে', 'katate': 'কাটাতে',
  'kora': 'করা', 'hoye': 'হয়ে', 'gese': 'গেছে', 'geche': 'গেছে', 'gechhe': 'গেছে', 'sesh': 'শেষ', 'shesh': 'শেষ', 'korechi': 'করেছি',
  'muche': 'মুছে', 'mucho': 'মুছো', 'bad': 'বাদ', 'bondho': 'বন্ধ', 'koro': 'করো', 'kore': 'করে',
  'reminder': 'রিমাইন্ডার', 'alarm': 'অ্যালার্ম', 'mone': 'মনে', 'koriye': 'করিয়ে', 'koraba': 'করাবে', 'korabe': 'করাবে', 'dio': 'দিও',
  'sokal': 'সকাল', 'sokale': 'সকালে', 'dupur': 'দুপুর', 'bikel': 'বিকেল', 'sondha': 'সন্ধ্যা', 'sondhya': 'সন্ধ্যা', 'rat': 'রাত', 'rate': 'রাতে', 'tay': 'টায়', 'ta-y': 'টায়',
  'protidin': 'প্রতিদিন', 'roj': 'রোজ', 'daily': 'প্রতিদিন',
  'kache': 'কাছে', 'theke': 'থেকে', 'kotha': 'কথা',
  'bazar': 'বাজার', 'dudh': 'দুধ', 'chul': 'চুল', 'doctor': 'ডাক্তার', 'daktar': 'ডাক্তার', 'bank': 'ব্যাংক', 'meeting': 'মিটিং', 'report': 'রিপোর্ট', 'file': 'ফাইল', 'ousudh': 'ওষুধ', 'oshudh': 'ওষুধ',
  // Money and people (owner, 29 Oct: "khalid amar kache 1 hajar taka pay").
  'taka': 'টাকা', 'tk': 'টাকা', 'taka.': 'টাকা', 'hajar': 'হাজার', 'hazar': 'হাজার', 'lakh': 'লাখ', 'lac': 'লাখ', 'sho': 'শো', 'dera': 'দেড়', 'arai': 'আড়াই',
  'dilam': 'দিলাম', 'dilaam': 'দিলাম', 'dichi': 'দিছি', 'disi': 'দিছি', 'diyechi': 'দিয়েছি', 'dise': 'দিছে', 'diche': 'দিছে', 'dilo': 'দিল', 'dey': 'দেয়',
  'nilam': 'নিলাম', 'nichi': 'নিছি', 'nisi': 'নিছি', 'nise': 'নিছে', 'niche': 'নিছে', 'nilo': 'নিল', 'niyechi': 'নিয়েছি',
  'pelam': 'পেলাম', 'paisi': 'পাইছি', 'paichi': 'পাইছি', 'pay': 'পায়', 'pai': 'পাই', 'pabo': 'পাব', 'pabe': 'পাবে', 'paben': 'পাবেন', 'debe': 'দেবে', 'dibe': 'দিবে', 'diben': 'দিবেন',
  'dhar': 'ধার', 'dhaar': 'ধার', 'shodh': 'শোধ', 'sodh': 'শোধ', 'ferot': 'ফেরত', 'ferat': 'ফেরত', 'baki.': 'বাকি',
  'khoroch': 'খরচ', 'khorch': 'খরচ', 'khoros': 'খরচ', 'kinlam': 'কিনলাম', 'kinsi': 'কিনছি', 'kinchi': 'কিনছি', 'kinechi': 'কিনেছি', 'bechlam': 'বেচলাম', 'bikri': 'বিক্রি',
  'ay': 'আয়', 'aay': 'আয়', 'beton': 'বেতন', 'salary': 'বেতন', 'bhara': 'ভাড়া', 'vara': 'ভাড়া', 'bill': 'বিল', 'bkash': 'বিকাশ', 'bikash': 'বিকাশ', 'nagad': 'নগদ',
  'hisab': 'হিসাব', 'hishab': 'হিসাব', 'hisabe': 'হিসাবে', 'ke': 'কে', 're': 'রে', 'ma': 'মা', 'baba': 'বাবা', 'bhai': 'ভাই', 'vai': 'ভাই', 'apu': 'আপু',
  'ami': 'আমি', 'amake': 'আমাকে', 'amr': 'আমার', 'tumi': 'তুমি', 'tomar': 'তোমার', 'or': 'ওর', 'tar': 'তার', 'diye': 'দিয়ে', 'dewa': 'দেওয়া', 'deya': 'দেওয়া', 'newa': 'নেওয়া', 'neya': 'নেওয়া',
  'lagbe': 'লাগবে', 'hoise': 'হইছে', 'hoyse': 'হইছে', 'hoyeche': 'হয়েছে', 'korlam': 'করলাম', 'korsi': 'করছি', 'korchi': 'করছি', 'lekho': 'লেখো', 'likho': 'লিখো', 'rakho': 'রাখো',
  'sob': 'সব', 'shob': 'সব', 'kom': 'কম', 'beshi': 'বেশি', 'ar': 'আর', 'na': 'না', 'ha': 'হ্যাঁ', 'haa': 'হ্যাঁ', 'hya': 'হ্যাঁ', 'thik': 'ঠিক', 'jonno': 'জন্য', 'jonne': 'জন্য', 'dorkar': 'দরকার',
  'note': 'নোট', 'call': 'কল', 'phone': 'ফোন', 'fon': 'ফোন', 'mash': 'মাস', 'mas': 'মাস', 'masher': 'মাসের', 'shoptah': 'সপ্তাহ', 'bochor': 'বছর', 'din': 'দিন', 'dine': 'দিনে',
  'ghonta': 'ঘণ্টা', 'minit': 'মিনিট', 'por': 'পর', 'pore': 'পরে', 'age': 'আগে', 'shukrobar': 'শুক্রবার', 'sukrobar': 'শুক্রবার', 'shonibar': 'শনিবার', 'robibar': 'রবিবার',
  'sombar': 'সোমবার', 'mongolbar': 'মঙ্গলবার', 'budhbar': 'বুধবার', 'brihospotibar': 'বৃহস্পতিবার', 'jonmodin': 'জন্মদিন', 'birthday': 'জন্মদিন',
};

/// Banglish words that are not Bangla words for what they sound like but
/// English (kept as they are when no dictionary entry says otherwise).
const _loanKeep = {'ok', 'okay', 'bkash', 'gp', 'pdf', 'id', 'nid', 'otp', 'pin', 'wifi', 'net', 'mb', 'gb'};

/// Words only Banglish uses (never English words).
const _banglishOnly = {
  'aj', 'aaj', 'ajke', 'kal', 'kalke', 'porshu', 'kaj', 'kajer', 'kajgulo', 'kam', 'talika', 'dao', 'dekhao', 'dekhan', 'bolo', 'chai', 'ki', 'koto', 'koyta', 'ache', 'ase', 'baki', 'amar', 'gulo',
  'hobe', 'jabo', 'korbo', 'kinbo', 'dibo', 'debo', 'kinte', 'dite', 'nite', 'jete', 'katate', 'kora', 'hoye', 'gese', 'geche', 'gechhe', 'sesh', 'shesh', 'korechi', 'muche', 'mucho', 'bondho', 'koro', 'kore',
  'mone', 'koriye', 'koraba', 'korabe', 'dio', 'sokal', 'sokale', 'dupur', 'bikel', 'sondha', 'sondhya', 'rate', 'tay', 'protidin', 'roj', 'kache', 'theke', 'kotha', 'bazar', 'dudh', 'chul', 'daktar', 'ousudh', 'oshudh', 'er', 'ta',
  'taka', 'hajar', 'hazar', 'dilam', 'dilaam', 'dichi', 'disi', 'diyechi', 'dise', 'diche', 'nilam', 'nichi', 'nisi', 'nise', 'niche', 'niyechi', 'pelam', 'paisi', 'paichi', 'pabo', 'pabe', 'paben',
  'dhar', 'dhaar', 'shodh', 'sodh', 'ferot', 'khoroch', 'khorch', 'kinlam', 'kinsi', 'kinchi', 'kinechi', 'bechlam', 'beton', 'bhara', 'vara', 'hisab', 'hishab', 'amake', 'ami', 'amr', 'tumi', 'tomar',
  'lagbe', 'hoise', 'hoyse', 'hoyeche', 'korlam', 'korsi', 'korchi', 'jonno', 'jonne', 'dorkar', 'masher', 'bochor', 'ghonta', 'shukrobar', 'sukrobar', 'shonibar', 'robibar', 'sombar', 'mongolbar',
  'budhbar', 'brihospotibar', 'jonmodin', 'bhai', 'vai', 'apu', 'diye', 'dewa', 'deya', 'newa', 'neya', 'sob', 'shob',
};

/// English sentence words: with any of them the message is English.
const _englishWords = {'a', 'an', 'the', 'to', 'is', 'are', 'and', 'my', 'me', 'please', 'add', 'send', 'show', 'remind', 'set', 'what', 'tomorrow', 'today', 'for', 'of', 'at', 'in', 'on', 'i', 'you', 'it', 'this', 'that', 'with'};

/// [said] in standard Bengali (see the file comment). Unchanged when there
/// is nothing to change.
String standardSpeech(String said, {Iterable<String> names = const []}) {
  var s = said;
  // Two-word forms first.
  for (final e in _dialect.entries.where((e) => e.key.contains(' '))) {
    s = s.replaceAll(RegExp('(?<=^|[\\s,।?!])${RegExp.escape(e.key)}(?=\$|[\\s,।?!])'), e.value);
  }
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // Banglish only when a word of it is there and no English sentence
  // words are ("Add a task, send the proposal" stays English).
  final lower = [for (final w in words) w.toLowerCase().replaceAll(RegExp(r'[,.?!।]'), '')];
  final banglishCore = lower.any(_banglishOnly.contains);
  final english = lower.any(_englishWords.contains);
  final mostlyLatin = banglishCore && !english && words.where((w) => RegExp(r'^[A-Za-z0-9]').hasMatch(w)).length * 2 > words.length;
  final out = StringBuffer();
  final parts = RegExp(r'\s+|[^\s]+').allMatches(s).map((m) => m[0]!).toList();
  for (final p in parts) {
    if (p.trim().isEmpty) {
      out.write(p);
      continue;
    }
    final m = RegExp(r'^(.*?)([,।?!.]*)$').firstMatch(p)!;
    final w = m[1]!, tail = m[2]!;
    final d = _dialect[w];
    if (d != null) {
      out.write('$d$tail');
      continue;
    }
    if (mostlyLatin) {
      final b = _banglish[w.toLowerCase()];
      if (b != null) {
        out.write('$b$tail');
        continue;
      }
      // "9tay", "10ta": a clock said in English letters.
      final clock = RegExp(r'^(\d{1,2})(?:ta|tay|tai|te)$', caseSensitive: false).firstMatch(w);
      if (clock != null) {
        out.write('${bnDigits(int.parse(clock[1]!))}টায়$tail');
        continue;
      }
      // Anything else in English letters is a name (or a word not listed):
      // a person already known by that sound, else written in Bangla as it
      // sounds ("khalid" → খালিদ), so the rules read one script.
      if (RegExp(r'^[A-Za-z]+$').hasMatch(w) && !_loanKeep.contains(w.toLowerCase()) && !_englishWords.contains(w.toLowerCase())) {
        out.write('${knownBySound(w, names) ?? banglaSound(w)}$tail');
        continue;
      }
    }
    out.write(p);
  }
  // "তালিকা থেকে সরিয়ে দাও": off the list is removing it ("সরাও" alone
  // may mean another day).
  final off = out.toString().replaceAllMapped(RegExp(r'(তালিকা|লিস্ট)\s+থেকে\s+(?:সরিয়ে\s+(?:দাও|দিন|দেন|ফেলো)|সরাও|সরান|উঠিয়ে\s+দাও|তুলে\s+দাও|কেটে\s+দাও)'), (m) => '${m[1]} থেকে মুছে দাও');
  // "কাজ টা", "রিমাইন্ডার গুলো": the ending joined to its word.
  return off.replaceAllMapped(RegExp(r'(\S)\s+(টা|টি|গুলো)(?=$|[\s,।?!])'), (m) => '${m[1]}${m[2]}');
}

// ── Banglish names, by sound ──

/// Latin letters → Bangla, longest first: consonants, then vowels as signs
/// after a consonant or letters of their own.
const _cons = [
  ('chh', 'ছ'), ('kh', 'খ'), ('gh', 'ঘ'), ('ch', 'চ'), ('jh', 'ঝ'), ('th', 'থ'), ('dh', 'ধ'), ('ph', 'ফ'), ('bh', 'ভ'), ('sh', 'শ'), ('ng', 'ং'), ('rh', 'ঢ়'),
  ('k', 'ক'), ('g', 'গ'), ('c', 'ক'), ('j', 'জ'), ('t', 'ত'), ('d', 'দ'), ('n', 'ন'), ('p', 'প'), ('f', 'ফ'), ('b', 'ব'), ('v', 'ভ'), ('m', 'ম'), ('y', 'য়'),
  ('r', 'র'), ('l', 'ল'), ('s', 'স'), ('h', 'হ'), ('z', 'জ'), ('q', 'ক'), ('x', 'ক্স'), ('w', 'ও'),
];
const _vowels = [
  ('ee', 'ী', 'ঈ'), ('oo', 'ু', 'উ'), ('oi', 'ৈ', 'ঐ'), ('ou', 'ৌ', 'ঔ'), ('aa', 'া', 'আ'),
  ('a', 'া', 'আ'), ('i', 'ি', 'ই'), ('u', 'ু', 'উ'), ('e', 'ে', 'এ'), ('o', 'ো', 'ও'),
];

/// [w] (English letters) written in Bangla as it sounds: "khalid" → খালিদ,
/// "nusrat" → নুসরাত. Good enough for a name the app has not met.
String banglaSound(String w) {
  final s = w.toLowerCase();
  final b = StringBuffer();
  var i = 0;
  var afterCons = false;
  while (i < s.length) {
    var hit = false;
    for (final (l, bn) in _cons) {
      if (s.startsWith(l, i)) {
        b.write(bn);
        i += l.length;
        afterCons = true;
        hit = true;
        break;
      }
    }
    if (hit) continue;
    for (final (l, sign, letter) in _vowels) {
      if (s.startsWith(l, i)) {
        b.write(afterCons ? sign : letter);
        i += l.length;
        afterCons = false;
        hit = true;
        break;
      }
    }
    if (!hit) {
      b.write(s[i]);
      i++;
      afterCons = false;
    }
  }
  return b.toString();
}

/// A name's sound skeleton: its consonants by kind, vowels left out — the
/// same for "khalid" and খালিদ, "rahim" and রহিম.
String soundKey(String name) {
  final s = name.toLowerCase();
  const bn = {
    'ক': 'k', 'খ': 'k', 'গ': 'g', 'ঘ': 'g', 'চ': 'c', 'ছ': 'c', 'জ': 'j', 'ঝ': 'j', 'য': 'j', 'ট': 't', 'ঠ': 't', 'ত': 't', 'থ': 't', 'ৎ': 't',
    'ড': 'd', 'ঢ': 'd', 'দ': 'd', 'ধ': 'd', 'ন': 'n', 'ণ': 'n', 'প': 'p', 'ফ': 'p', 'ব': 'b', 'ভ': 'b', 'ম': 'm', 'র': 'r', 'ড়': 'r', 'ঢ়': 'r',
    'ল': 'l', 'শ': 's', 'ষ': 's', 'স': 's', 'হ': 'h', 'য়': 'y', 'ং': 'n', 'ঞ': 'n', 'ঙ': 'n',
  };
  const lat = [
    ('chh', 'c'), ('kh', 'k'), ('gh', 'g'), ('ch', 'c'), ('jh', 'j'), ('th', 't'), ('dh', 'd'), ('ph', 'p'), ('bh', 'b'), ('sh', 's'), ('ng', 'n'), ('rh', 'r'),
    ('k', 'k'), ('g', 'g'), ('c', 'k'), ('j', 'j'), ('z', 'j'), ('t', 't'), ('d', 'd'), ('n', 'n'), ('p', 'p'), ('f', 'p'), ('b', 'b'), ('v', 'b'), ('m', 'm'),
    ('r', 'r'), ('l', 'l'), ('s', 's'), ('h', 'h'), ('q', 'k'), ('y', 'y'),
  ];
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final one = s[i];
    if (bn.containsKey(one)) {
      out.write(bn[one]);
      i++;
      continue;
    }
    var hit = false;
    for (final (l, k) in lat) {
      if (s.startsWith(l, i)) {
        out.write(k);
        i += l.length;
        hit = true;
        break;
      }
    }
    if (!hit) i++;
  }
  // Two of the same in a row are one ("hasan"/"hassan").
  return out.toString().replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!).replaceAll('y', '');
}

/// One of [names] (in Bangla) that sounds like [w]: its first word's
/// skeleton is the same. Null when none, or when two different ones do.
String? knownBySound(String w, Iterable<String> names) {
  final k = soundKey(w);
  if (k.length < 2) return null;
  final hits = <String>{};
  for (final n in names) {
    final first = n.trim().split(RegExp(r'\s+')).first;
    if (first.isNotEmpty && soundKey(first) == k) hits.add(first);
  }
  return hits.length == 1 ? hits.first : null;
}
