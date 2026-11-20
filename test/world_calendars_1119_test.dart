// The world's calendars (owner, 19 Nov). Each date below is from the
// calendar's own published sources; the code was also checked day by day
// for 1944–2098 against independent libraries (lunardate, KASI's
// korean_lunar_calendar, convertdate, nepali_datetime).
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/world_calendars.dart';
import 'package:flutter_test/flutter_test.dart';

(int, int, int) ymd(String id, int y, int m, int d) {
  final c = calDate(id, DateTime(y, m, d))!;
  return (c.year, c.month, c.day);
}

void main() {
  setUp(() => isEn = true);
  tearDown(() => isEn = false);

  test('Chinese: new years and a leap month', () {
    expect(ymd('chinese', 2024, 2, 10), (2024, 1, 1)); // Year of the Dragon
    expect(ymd('chinese', 2026, 2, 17), (2026, 1, 1)); // Year of the Horse
    expect(ymd('chinese', 2026, 2, 16), (2025, 12, 29));
    expect(ymd('chinese', 2023, 9, 29), (2023, 8, 15)); // Mid-Autumn
    final leap = calDate('chinese', DateTime(2023, 3, 22))!; // 2023: leap second month
    expect((leap.month, leap.day, leap.leap), (2, 1, true));
    expect(calDate('chinese', DateTime(2026, 2, 17))!.yearLabel, 'Year of the Horse');
    expect(calDate('chinese', DateTime(2026, 11, 19))!.native, '丙午年 十月十一');
    expect(calDate('chinese', DateTime(1899, 1, 1)), isNull);
  });

  test('Korean: Seollal and Chuseok, Dangi year', () {
    expect(ymd('korean', 2026, 2, 17), (4359, 1, 1));
    expect(ymd('korean', 2025, 10, 6), (4358, 8, 15));
  });

  test('Hebrew: Rosh Hashanah, Passover, Adar in leap and common years', () {
    expect(ymd('hebrew', 2025, 9, 23), (5786, 1, 1));
    expect(ymd('hebrew', 2026, 9, 12), (5787, 1, 1));
    final pesach = calDate('hebrew', DateTime(2025, 4, 13))!;
    expect((pesach.monthName, pesach.day), ('Nisan', 15));
    expect(calDate('hebrew', DateTime(2024, 3, 24))!.monthName, 'Adar II'); // Purim 5784 (leap)
    expect(calDate('hebrew', DateTime(2025, 3, 14))!.monthName, 'Adar'); // Purim 5785
    expect(calDate('hebrew', DateTime(2026, 11, 19))!.native, 'ט׳ בכסלו תשפ״ז');
  });

  test('Persian: Nowruz', () {
    expect(ymd('persian', 2025, 3, 21), (1404, 1, 1));
    expect(ymd('persian', 2026, 3, 21), (1405, 1, 1));
    expect(ymd('persian', 2024, 3, 20), (1403, 1, 1));
    expect(ymd('persian', 2026, 11, 19), (1405, 8, 28));
  });

  test('Saka, Vikram Samvat, Ethiopian, Julian', () {
    expect(ymd('saka', 2026, 3, 22), (1948, 1, 1));
    expect(ymd('saka', 2024, 3, 21), (1946, 1, 1)); // a leap year
    expect(ymd('vikram', 2026, 4, 14), (2083, 1, 1)); // Nepali new year
    expect(ymd('ethiopian', 2026, 9, 11), (2019, 1, 1)); // Enkutatash
    expect(ymd('ethiopian', 2027, 9, 12), (2020, 1, 1)); // before a Gregorian leap year
    expect(ymd('ethiopian', 2026, 1, 7), (2018, 4, 29)); // Ethiopian Christmas
    expect(ymd('julian', 2026, 1, 7), (2025, 12, 25)); // Orthodox Christmas
  });

  test('Thai and Japanese', () {
    expect(calDate('thai', DateTime(2026, 11, 19))!.yearLabel, 'BE 2569');
    expect(calDate('japanese', DateTime(2019, 5, 1))!.native, '令和元年5月1日');
    expect(calDate('japanese', DateTime(2019, 4, 30))!.yearLabel, 'Heisei 31');
  });

  test('the choice: Bangla and Hijri by default, at most two, "none" for English only', () {
    expect(parseCalendars(null), ['bangla', 'hijri']);
    expect(parseCalendars('none'), isEmpty);
    expect(parseCalendars('chinese,x,hebrew,persian'), ['chinese', 'hebrew']);
    expect(calendarsPref(const []), 'none');
  });
}
