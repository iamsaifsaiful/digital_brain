// Learning samples (brief step F.8 / G): with the member's consent only,
// some readings go to the server so the model can be taught again — names
// replaced on the phone ("<নাম১>"), never anything secret, never a phone
// number or a code. The server checks again and refuses such samples.
import '../logic/parser.dart' show mentionsSecret, normalize;

/// The app's version, set at start-up (lib/main.dart) — sent with each sample.
String nluAppVersion = '';

/// The version of the consent text the member agreed to (sent with every batch).
const nluConsentVer = '1';

/// The words with names replaced, or null when this message must stay on
/// the phone (a secret, a phone number, a long code).
String? delexicalize(String text, Iterable<String> names) {
  if (mentionsSecret(text)) return null;
  final digits = text.replaceAllMapped(RegExp('[০-৯]'), (m) => '${m[0]!.codeUnitAt(0) - 0x09E6}').replaceAll(RegExp(r'[\s\-]'), '');
  if (RegExp(r'0?1[3-9]\d{8}').hasMatch(digits)) return null;
  if (RegExp(r'\d{6,}').hasMatch(digits) && !RegExp(r'\d{6,}(টাকা|tk|/=)').hasMatch(digits)) return null;
  var out = text;
  var n = 0;
  final seen = <String, String>{};
  // Longest names first, so "রবিন হায়দার" goes before "রবিন".
  final list = {for (final x in names) x.trim()}.where((x) => x.length >= 2).toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final name in list) {
    // The name as a word, maybe with a case ending (রবিনকে, তুবার, রবিনের) — never inside another word.
    final re = RegExp('(?<![\\p{L}\\p{M}])${RegExp.escape(name)}(?=(?:কে|র|ের|য়ের|এর|দের|রা|ও|ই|কেও|রও)?(?![\\p{L}\\p{M}]))', unicode: true);
    if (!re.hasMatch(out)) continue;
    final tag = seen.putIfAbsent(normalize(name), () => '<নাম${'০১২৩৪৫৬৭৮৯'[(++n) % 10]}>');
    out = out.replaceAll(re, tag);
  }
  return out;
}

/// One sample as the server takes it (POST /nlu/samples).
Map<String, Object?> nluSample({
  required String textDelex,
  required String state,
  required List<(String, double)> local,
  required List<String> finalIntents,
  required String appVer,
  required String modelVer,
  String signal = '',
}) =>
    {
      'text_delex': textDelex,
      'state': state,
      'local_json': {'pieces': [for (final (i, c) in local) {'intent': i, 'conf': double.parse(c.toStringAsFixed(3))}]},
      'local_conf': local.isEmpty ? 0 : local.map((x) => x.$2).reduce((a, b) => a < b ? a : b),
      'final_json': {'pieces': [for (final i in finalIntents) {'intent': i}]},
      'signal': signal,
      'app_ver': appVer,
      'model_ver': modelVer,
    };
