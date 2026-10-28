/// How often a reminder rings, said plainly (owner, 28 Oct): "প্রতি শনিবার",
/// "প্রতি শনি ও মঙ্গলবার", "শুক্রবার বাদে প্রতিদিন".
library;

import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';

/// The week as it is counted here: Saturday first.
const weekOrder = [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday];

String _list(List<String> xs) => xs.length <= 1 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} ${tr('ও')} ${xs.last}';

/// "শনি", "মঙ্গল": a weekday's name without "বার" (Bangla), the short name in English.
String _stem(int d) => isEn ? dayShort(d) : dayName(d).replaceFirst(RegExp(r'বার$'), '');

String repeatText(Reminder r) {
  if (r.repeat != Repeat.weekly) return tr(r.repeat.label);
  final days = r.ringDays;
  if (days.length >= 7) return tr('প্রতিদিন');
  if (days.length >= 5) {
    final off = [for (final d in weekOrder) if (!days.contains(d)) d];
    final names = off.length == 1 ? [dayName(off.first)] : [for (final d in off) _stem(d)];
    return trf('{0}{1} বাদে প্রতিদিন', [_list(names), off.length == 1 || isEn ? '' : 'বার']);
  }
  final on = [for (final d in weekOrder) if (days.contains(d)) d];
  if (on.length == 1) return trf('প্রতি {0}', [dayName(on.first)]);
  return trf('প্রতি {0}{1}', [_list([for (final d in on) _stem(d)]), isEn ? '' : 'বার']);
}
