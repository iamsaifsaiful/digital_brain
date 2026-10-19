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
};

/// [said] in standard Bengali (see the file comment). Unchanged when there
/// is nothing to change.
String standardSpeech(String said) {
  var s = said;
  // Two-word forms first.
  for (final e in _dialect.entries.where((e) => e.key.contains(' '))) {
    s = s.replaceAll(RegExp('(?<=^|[\\s,।?!])${RegExp.escape(e.key)}(?=\$|[\\s,।?!])'), e.value);
  }
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final mostlyLatin = words.where((w) => RegExp(r'^[A-Za-z0-9]').hasMatch(w)).length * 2 > words.length;
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
    }
    out.write(p);
  }
  // "কাজ টা", "রিমাইন্ডার গুলো": the ending joined to its word.
  return out.toString().replaceAllMapped(RegExp(r'(\S)\s+(টা|টি|গুলো)(?=$|[\s,।?!])'), (m) => '${m[1]}${m[2]}');
}
