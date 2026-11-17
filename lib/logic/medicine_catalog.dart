/// Common medicines sold in Bangladesh: the name on the box, what is in it
/// and, in one line, what it is usually taken for. Kept in the app (nothing
/// typed leaves the phone). Owner, 17 Nov: "ওষুধের নাম লিখলে লাইভ সার্চ
/// দেখাবে এবং এই ওষুধ সাধারণত কেন খায়, তা নিচে এক বাক্যে লেখা থাকবে।"
/// General information only — the form says to follow the doctor.
class MedInfo {
  const MedInfo(this.bn, this.en, this.genericBn, this.genericEn, this.use);
  final String bn;
  final String en;
  final String genericBn;
  final String genericEn;
  final String use;
}

const medicineCatalog = <MedInfo>[
  MedInfo('নাপা', 'Napa', 'প্যারাসিটামল', 'Paracetamol', 'জ্বর আর ব্যথা কমাতে'),
  MedInfo('নাপা এক্সট্রা', 'Napa Extra', 'প্যারাসিটামল + ক্যাফেইন', 'Paracetamol + Caffeine', 'মাথাব্যথা আর জ্বর কমাতে'),
  MedInfo('এইস', 'Ace', 'প্যারাসিটামল', 'Paracetamol', 'জ্বর আর ব্যথা কমাতে'),
  MedInfo('সেকলো', 'Seclo', 'ওমিপ্রাজল', 'Omeprazole', 'গ্যাস্ট্রিক, বুক জ্বালা আর পেটের আলসারে'),
  MedInfo('লোসেকটিল', 'Losectil', 'ওমিপ্রাজল', 'Omeprazole', 'গ্যাস্ট্রিক, বুক জ্বালা আর পেটের আলসারে'),
  MedInfo('সার্জেল', 'Sergel', 'ইসোমিপ্রাজল', 'Esomeprazole', 'গ্যাস্ট্রিক আর বুক জ্বালায়'),
  MedInfo('ম্যাক্সপ্রো', 'Maxpro', 'ইসোমিপ্রাজল', 'Esomeprazole', 'গ্যাস্ট্রিক আর বুক জ্বালায়'),
  MedInfo('প্যান্টোনিক্স', 'Pantonix', 'প্যান্টোপ্রাজল', 'Pantoprazole', 'গ্যাস্ট্রিক আর বুক জ্বালায়'),
  MedInfo('ফেক্সো', 'Fexo', 'ফেক্সোফেনাডিন', 'Fexofenadine', 'অ্যালার্জি, হাঁচি আর চুলকানিতে'),
  MedInfo('অ্যালাট্রল', 'Alatrol', 'সেটিরিজিন', 'Cetirizine', 'অ্যালার্জি, সর্দি আর চুলকানিতে'),
  MedInfo('মোনাস', 'Monas', 'মন্টিলুকাস্ট', 'Montelukast', 'অ্যাজমা আর অ্যালার্জি নিয়ন্ত্রণে'),
  MedInfo('অ্যামডোকাল', 'Amdocal', 'অ্যামলোডিপিন', 'Amlodipine', 'উচ্চ রক্তচাপ কমাতে'),
  MedInfo('ক্যামলোডিন', 'Camlodin', 'অ্যামলোডিপিন', 'Amlodipine', 'উচ্চ রক্তচাপ কমাতে'),
  MedInfo('অসার্টিল', 'Osartil', 'লোসার্টান', 'Losartan', 'উচ্চ রক্তচাপ কমাতে'),
  MedInfo('অ্যাঞ্জিলক', 'Angilock', 'লোসার্টান', 'Losartan', 'উচ্চ রক্তচাপ কমাতে'),
  MedInfo('বিসলোল', 'Bislol', 'বিসোপ্রোলল', 'Bisoprolol', 'উচ্চ রক্তচাপ আর হৃদ্‌রোগে'),
  MedInfo('কমেট', 'Comet', 'মেটফরমিন', 'Metformin', 'ডায়াবেটিসে রক্তের চিনি কমাতে'),
  MedInfo('সেকরিন', 'Secrin', 'গ্লিমেপিরাইড', 'Glimepiride', 'ডায়াবেটিসে রক্তের চিনি কমাতে'),
  MedInfo('রসুভা', 'Rosuva', 'রসুভাস্ট্যাটিন', 'Rosuvastatin', 'রক্তের কোলেস্টেরল কমাতে'),
  MedInfo('অ্যাটোভা', 'Atova', 'অ্যাটোরভাস্ট্যাটিন', 'Atorvastatin', 'রক্তের কোলেস্টেরল কমাতে'),
  MedInfo('ইকোস্প্রিন', 'Ecosprin', 'অ্যাসপিরিন (কম মাত্রা)', 'Aspirin', 'রক্ত জমাট বাঁধা ঠেকাতে, হৃদ্‌রোগে'),
  MedInfo('থাইরক্স', 'Thyrox', 'লেভোথাইরক্সিন', 'Levothyroxine', 'থাইরয়েড হরমোন কম থাকলে'),
  MedInfo('ক্যালবো-ডি', 'Calbo-D', 'ক্যালসিয়াম + ভিটামিন ডি', 'Calcium + Vitamin D', 'হাড় মজবুত রাখতে'),
  MedInfo('জিম্যাক্স', 'Zimax', 'অ্যাজিথ্রোমাইসিন', 'Azithromycin', 'ব্যাকটেরিয়ার সংক্রমণে (অ্যান্টিবায়োটিক)'),
  MedInfo('সেফ-৩', 'Cef-3', 'সেফিক্সিম', 'Cefixime', 'ব্যাকটেরিয়ার সংক্রমণে (অ্যান্টিবায়োটিক)'),
  MedInfo('ফ্লাজিল', 'Flagyl', 'মেট্রোনিডাজল', 'Metronidazole', 'আমাশয় আর কিছু সংক্রমণে'),
  MedInfo('মোটিগাট', 'Motigut', 'ডমপেরিডন', 'Domperidone', 'বমি ভাব আর পেট ফাঁপায়'),
  MedInfo('টোফেন', 'Tofen', 'কিটোটিফেন', 'Ketotifen', 'অ্যালার্জি আর অ্যাজমার টান ঠেকাতে'),
];

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-‌]'), '');

/// Up to [max] medicines whose name (Bangla or English) or what is in it
/// begins with — or, after those, contains — what was typed.
List<MedInfo> searchMedicines(String q, {int max = 4}) {
  final n = _norm(q);
  if (n.length < 2) return const [];
  final starts = <MedInfo>[], has = <MedInfo>[];
  for (final m in medicineCatalog) {
    final keys = [m.bn, m.en, m.genericBn, m.genericEn].map(_norm);
    if (keys.any((k) => k.startsWith(n))) {
      starts.add(m);
    } else if (keys.any((k) => k.contains(n))) {
      has.add(m);
    }
  }
  return [...starts, ...has].take(max).toList();
}

/// The medicine with exactly this name, if it is in the list.
MedInfo? medicineNamed(String name) {
  final n = _norm(name);
  if (n.isEmpty) return null;
  for (final m in medicineCatalog) {
    if (_norm(m.bn) == n || _norm(m.en) == n) return m;
  }
  return null;
}
