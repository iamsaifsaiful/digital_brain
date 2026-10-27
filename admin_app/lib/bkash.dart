/// Reads one bKash message (English or Bangla) the way the server and the
/// SMS receiver do (plugin bkash.php, BkashSms.kt): money received only.
/// Returns {trx, amount, sender, at} or null. Used when a message is pasted.
library;

const _bnDigits = {'০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4', '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9'};

String _ascii(String s) => s.split('').map((c) => _bnDigits[c] ?? c).join();

String bkashPhone(String s) {
  var d = _ascii(s).replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('880')) d = d.substring(2);
  return RegExp(r'^01[3-9]\d{8}$').hasMatch(d) ? d : '';
}

Map<String, dynamic>? parseBkash(String raw) {
  final t = _ascii(raw.trim());
  if (!RegExp(r'(you have received|received payment|পেয়েছেন|গ্রহণ করেছেন)', caseSensitive: false).hasMatch(t)) return null;
  final trx = RegExp(r'TrxID[:\s#]*([A-Z0-9]{8,12})\b', caseSensitive: false).firstMatch(t)?.group(1)?.toUpperCase();
  if (trx == null) return null;
  final a = RegExp(r'Tk\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false).firstMatch(t)?.group(1) ??
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*টাকা').firstMatch(t)?.group(1) ??
      RegExp(r'৳\s*([\d,]+(?:\.\d{1,2})?)').firstMatch(t)?.group(1);
  final amount = a == null ? null : double.tryParse(a.replaceAll(',', ''))?.floor();
  if (amount == null || amount <= 0) return null;
  final from = RegExp(r'from\s+(\+?[\d\-\s]{11,16})', caseSensitive: false).firstMatch(t)?.group(1) ?? RegExp(r'(\+?[\d\-]{11,16})\s*(?:নম্বর\s*)?থেকে').firstMatch(t)?.group(1);
  var at = '';
  final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})').firstMatch(t);
  if (m != null) {
    // bKash writes Bangladesh time (UTC+6).
    final local = DateTime.utc(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!), int.parse(m[4]!), int.parse(m[5]!));
    at = local.subtract(const Duration(hours: 6)).toIso8601String();
  }
  return {'trx': trx, 'amount': amount, 'sender': from == null ? '' : bkashPhone(from), 'at': at};
}
