// Holidays abroad (owner, 29 Oct: "যে দেশে সে দেশের ছুটি"). Most countries
// come from Nager.Date (services/weather.dart); the Gulf, Malaysia and
// Pakistan — where many members work and Nager.Date has no list — are
// worked out here: the Islamic days from the Hijri calendar (a day may
// differ with the moon seen there) and the national days that never move.
import 'calendar_bd.dart' show hijriDate;

/// A public holiday abroad: its day and its name (English and local).
class AbroadHoliday {
  const AbroadHoliday(this.date, this.name, {this.local = ''});
  final DateTime date;
  final String name, local;

  Map<String, Object?> toJson() => {'d': date.toIso8601String().substring(0, 10), 'n': name, if (local.isNotEmpty) 'l': local};
  static AbroadHoliday? fromJson(Object? j) {
    if (j is! Map) return null;
    final d = DateTime.tryParse('${j['d'] ?? ''}');
    return d == null ? null : AbroadHoliday(d, '${j['n'] ?? ''}', local: '${j['l'] ?? ''}');
  }
}

/// Countries listed here rather than asked from the web.
const builtInHolidayCountries = {'SA', 'AE', 'QA', 'KW', 'OM', 'BH', 'MY', 'PK'};

/// [cc]'s holidays in [year], worked out on the phone; null when [cc] is
/// not one of [builtInHolidayCountries]. [adjust]: days the Hijri date is
/// moved for the moon there.
List<AbroadHoliday>? builtInHolidays(String cc, int year, {int adjust = 1}) {
  if (!builtInHolidayCountries.contains(cc)) return null;
  final out = <AbroadHoliday>[];
  void fixed(int m, int d, String name) => out.add(AbroadHoliday(DateTime(year, m, d), name));
  // The Islamic days: (Hijri month, first day, how many days, name).
  final islamic = <(int, int, int, String)>[
    (10, 1, cc == 'PK' || cc == 'MY' ? 2 : 3, 'Eid al-Fitr'),
    (12, 10, cc == 'PK' || cc == 'MY' ? 2 : 3, 'Eid al-Adha'),
    if (cc != 'MY' && cc != 'PK') (12, 9, 1, 'Arafat Day'),
    if (cc != 'SA') (1, 1, 1, 'Islamic New Year'),
    if (cc != 'SA') (3, 12, 1, "Prophet's Birthday"),
    if (cc == 'PK') (1, 9, 2, 'Ashura'),
    if (cc == 'KW' || cc == 'OM') (7, 27, 1, "Isra and Mi'raj"),
  ];
  for (var d = DateTime(year, 1, 1); d.year == year; d = d.add(const Duration(days: 1))) {
    final h = hijriDate(d, adjust: adjust);
    for (final (m, first, n, name) in islamic) {
      if (h.month == m && h.day >= first && h.day < first + n) out.add(AbroadHoliday(d, name));
    }
  }
  switch (cc) {
    case 'SA':
      fixed(2, 22, 'Founding Day');
      fixed(9, 23, 'Saudi National Day');
    case 'AE':
      fixed(1, 1, "New Year's Day");
      fixed(12, 2, 'National Day');
      fixed(12, 3, 'National Day');
    case 'QA':
      fixed(12, 18, 'Qatar National Day');
    case 'KW':
      fixed(1, 1, "New Year's Day");
      fixed(2, 25, 'National Day');
      fixed(2, 26, 'Liberation Day');
    case 'BH':
      fixed(1, 1, "New Year's Day");
      fixed(5, 1, 'Labour Day');
      fixed(12, 16, 'National Day');
      fixed(12, 17, 'National Day');
    case 'MY':
      fixed(5, 1, 'Labour Day');
      fixed(8, 31, 'National Day (Merdeka)');
      fixed(9, 16, 'Malaysia Day');
      fixed(12, 25, 'Christmas Day');
    case 'PK':
      fixed(2, 5, 'Kashmir Solidarity Day');
      fixed(3, 23, 'Pakistan Day');
      fixed(5, 1, 'Labour Day');
      fixed(8, 14, 'Independence Day');
      fixed(11, 9, 'Iqbal Day');
      fixed(12, 25, 'Quaid-e-Azam Day');
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}
