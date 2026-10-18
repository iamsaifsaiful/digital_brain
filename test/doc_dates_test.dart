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

  Map<String, String> fields(String s) => {for (final f in docFieldsIn(s)) f.label: f.value};

  test('a national ID card: name, number, date of birth', () {
    final f = fields('Government of the People\'s Republic of Bangladesh\nNational ID Card\nName\nMD SAIFUL ISLAM\nDate of Birth 05 Jan 1990\nID NO: 1234 567 890');
    expect(f['নাম'], 'MD SAIFUL ISLAM');
    expect(f['জন্মতারিখ'], '৫ জানুয়ারি ১৯৯০');
    expect(f['NID নম্বর'], '1234567890');
  });

  test('a passport: from the printed labels and the machine lines', () {
    final f = fields('PASSPORT\nPassport No.\nA01234567\nDate of Issue 12 MAY 2021\nDate of Expiry 11 MAY 2031\nP<BGDISLAM<<MD<SAIFUL<<<<<<<<<<<<<<<<<<<<<<<\nA012345674BGD9001057M3105115<<<<<<<<<<<<<<02');
    expect(f['পাসপোর্ট নম্বর'], 'A01234567');
    expect(f['নাম'], 'MD SAIFUL ISLAM');
    expect(f['জন্মতারিখ'], '৫ জানুয়ারি ১৯৯০');
    expect(f['ইস্যুর তারিখ'], '১২ মে ২০২১');
    expect(f.containsKey('মেয়াদ শেষ'), isFalse, reason: 'the expiry has its own place');
  });

  test('a phone receipt: invoice, model, IMEI, purchase date, warranty', () {
    final f = fields('SAMSUNG BRAND SHOP\nInvoice No: INV-20931\nInvoice Date: 12/05/2026\nModel: Galaxy A35\nIMEI 1: 356789012345678\nWarranty: 1 Year');
    expect(f['রসিদ / ইনভয়েস নম্বর'], 'INV-20931');
    expect(f['কেনার তারিখ'], '১২ মে ২০২৬');
    expect(f['মডেল'], 'Galaxy A35');
    expect(f['IMEI'], '356789012345678');
    expect(f['ওয়ারেন্টি'], '১ বছর');
  });

  test('nothing labelled: nothing made up', () {
    expect(docFieldsIn('Happy birthday!\nLove, Rina'), isEmpty);
  });
}
