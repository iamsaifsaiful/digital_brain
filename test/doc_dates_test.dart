// Reading the warranty / expiry date from a photo's recognised text (b38: "ছবি থেকে ওয়ারেন্টির তারিখ").
import 'package:digital_brain/logic/doc_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 18);
  DateTime? read(String s) => docDateIn(s, now)?.date;

  test('a date printed after an expiry word', () {
    expect(read('PASSPORT\nDate of Expiry\n12 MAY 2031'), DateTime(2031, 5, 12));
    expect(read('Warranty valid till: 15/03/2027'), DateTime(2027, 3, 15));
    expect(read('EXP 08/2027'), DateTime(2027, 8, 31));
    expect(read('Best before: 2027-01-09'), DateTime(2027, 1, 9));
    expect(read('Warranty period: 01-02-2026 to 31-01-2028'), DateTime(2028, 1, 31));
    expect(read('Valid until May 4, 2029'), DateTime(2029, 5, 4));
  });

  test('"1 Year Warranty" counts from the purchase date', () {
    final d = docDateIn('WALTON PLAZA\nInvoice Date: 12/05/2026\nRefrigerator WFC-3F5\nWarranty: 1 Year', now)!;
    expect(d.date, DateTime(2027, 5, 12));
    expect(d.fromPeriod, isTrue);
    expect(d.warranty, isTrue);
    expect(read('Date 03.09.2026\n6 months warranty'), DateTime(2027, 3, 3));
  });

  test('nothing clear: nothing guessed', () {
    expect(read('Invoice 12/05/2026 Total 45,000'), isNull);
    expect(read('Warranty card\nModel X'), isNull);
    expect(read('Warranty 2 years\nDate 01/01/2026\nDelivery 05/01/2026'), DateTime(2028, 1, 1), reason: 'the date by a purchase word');
  });
}
