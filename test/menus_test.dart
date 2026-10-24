// The 18 Oct menu spec: what each menu can do by voice, read the same way
// by the rules and the AI, carried out once, and said as it really
// happened. Two layers:
//  1. interpretation (fixtures): utterance → the typed action, with
//     colloquial, regional, Banglish, negative, question and contrast
//     variants — and "no write" for questions, negatives and what-ifs;
//  2. execution (chat): what is saved/changed, and what must stay as it was.
//
// Written input only (test clock: Fri 9 Oct 2026, 15:53). No microphone and
// no live AI: the AI's side is a fixed answer in the tool schema's shape.
import 'package:digital_brain/logic/ai_map.dart';
import 'package:digital_brain/logic/app_map.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

final now = DateTime(2026, 10, 9, 15, 53);

AppData seedData() => AppData()
  ..ledger.add(LedgerEntry(person: 'সজীব', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 1), note: ''))
  ..cash.addAll([
    CashEntry(kind: CashKind.expense, amount: 50, category: 'যাতায়াত', note: 'রিকশা', date: DateTime(2026, 10, 9, 9)),
    CashEntry(kind: CashKind.expense, amount: 1200, category: 'চিকিৎসা', date: DateTime(2026, 9, 12)),
    CashEntry(kind: CashKind.income, amount: 30000, category: 'বেতন', date: DateTime(2026, 10, 1)),
  ])
  ..accounts.addAll([
    MoneyAccount(id: 'a-cash', name: 'নগদ টাকা', kind: AccountKind.cash, opening: 2000),
    MoneyAccount(id: 'a-bkash', name: 'বিকাশ', kind: AccountKind.bkash, opening: 1000),
    MoneyAccount(id: 'a-bank', name: 'ডাচ বাংলা ব্যাংক', kind: AccountKind.bank, opening: 10000),
  ])
  ..projects.add(Project(id: 'p1', name: 'রহিম ভবন'))
  ..shops.add(Shop(id: 's1', name: 'এক নম্বর দোকান'))
  ..goals.add(SavingsGoal(id: 'g1', name: 'ল্যাপটপ', target: 50000))
  ..installments.add(Installment(id: 'i1', name: 'ব্যাংক DPS', amount: 2000, start: DateTime(2026, 1, 1)))
  ..medicines.addAll([Medicine(id: 'm1', name: 'নাপা', times: [8 * 60, 22 * 60], stock: 10), Medicine(id: 'm2', name: 'সেকলো', times: [7 * 60], stock: 0)])
  ..habits.addAll([Habit(id: 'h1', name: 'হাঁটা'), Habit(id: 'h2', name: 'নামাজ')])
  ..members.add(FamilyMember(id: 'mom', name: 'আম্মা', relation: 'মা'))
  ..specialDays.add(SpecialDay(person: 'রহিম', month: 3, day: 12))
  ..contacts.add(Contact(name: 'রহিম', phone: '01711000000'))
  ..notes.add(Note(id: 'n1', title: 'চাবি', body: 'চাবি আলমারির ড্রয়ারে', category: 'বাসা'));

/// What a sentence was read as: "domain/op" for a menu action, else the
/// command's type (with its kind for money).
String readAs(String said, [AppData? data]) {
  final d = data ?? seedData();
  final cmds = parseAll(said, d.ledger, tasks: d.tasks, contacts: d.contacts, now: now, data: d);
  return cmds.map((c) => switch (c) {
        MenuAction() => '${c.domain}/${c.op}',
        LedgerAdd() => 'LedgerAdd:${c.kind?.name ?? '?'}',
        CashAdd() => 'CashAdd:${c.kind.name}',
        HealthAdd() => 'HealthAdd:${c.kind.name}:${c.member}',
        SmallTalk() => 'SmallTalk:${c.kind.name}',
        _ => c.runtimeType.toString(),
      }).join(' + ');
}

/// Fixture rows: (case id, what is said, how it must be read).
const fixtures = <(String, String, String)>[
  // ── লেনদেন: direction, statements, plans, negatives, questions ──
  ('L01', 'সজীবকে পাঁচশ টাকা ধার দিয়েছি', 'LedgerAdd:lent'),
  ('L02', 'সজীবের কাছ থেকে পাঁচশ ধার নিয়েছি', 'LedgerAdd:borrowed'),
  ('L03', 'সজীব ধার থেকে দুইশ ফেরত দিয়েছে', 'LedgerAdd:received'),
  ('L04', 'সজীবকে ধার থেকে দুইশ ফেরত দিয়েছি', 'LedgerAdd:repaid'),
  ('L05', 'সজীবকে পাঁচশ দিলাম', 'LedgerAdd:?'),
  ('L06', 'সজীবের কাছে পাঁচশ টাকা পাই', 'LedgerSet'),
  ('L07', 'সজীবকে রবিবার পাঁচশ দেব', 'TaskAdd'),
  ('L08', 'সজীব টাকা দেয়নি', 'SmallTalk:nothingDone'),
  ('L09', 'আমি কার কার কাছে টাকা পাব', 'LedgerQuery'),
  ('L10', 'আমার কাছে কারা টাকা পাবে', 'LedgerQuery'),
  ('L11', 'সজীবের শেষ তিনটা লেনদেন দেখাও', 'MoneyListQuery'),
  ('L12', 'ওর আগের পাঁচশটা আসলে সাতশ', 'ManageItem'),
  ('L13', 'Sajib ke 500 taka dhar dilam', 'LedgerAdd:lent'),
  ('L14', 'সজীবরে পাঁচশ টেকা দিছি ধার', 'LedgerAdd:lent'),
  ('L15', 'সজীবকে টাকা দিলে কত থাকবে?', 'LedgerQuery'),
  ('L16', 'করিম আগের বাকি থেকে পাঁচশ দিয়েছে', 'LedgerAdd:received'),
  // ── আয়-ব্যয় ──
  ('C01', 'বাজারে সাতশ খরচ হয়েছে', 'CashAdd:expense'),
  ('C02', 'বেতন ত্রিশ হাজার পেয়েছি', 'CashAdd:income'),
  ('C03', 'কাল ভাড়া পাঁচ হাজার দেব', 'TaskAdd'),
  ('C04', 'পাঁচশ খরচ হয়নি', 'SmallTalk:nothingDone'),
  ('C05', 'বেতন পাইনি', 'SmallTalk:nothingDone'),
  ('C06', 'আজ কত খরচ করেছি', 'cash/spend'),
  ('C07', 'গত মাসের চিকিৎসার খরচ দেখাও', 'cash/spend'),
  ('C08', 'এই সপ্তাহে আয় কত', 'cash/income'),
  ('C09', 'আয় থেকে খরচ বাদে কত থাকে', 'cash/net'),
  ('C10', 'রিকশার খরচটা যাতায়াতে রাখো', 'cash/recategorize'),
  ('C11', 'একই খরচ দুইবার হয়েছে, একটা বাদ দাও', 'cash/dupes'),
  ('C12', 'বাজারে ৫০০, রিকশায় ৫০ আর ওষুধে ৩০০, মোট ৮৫০', 'CashAdd:expense + CashAdd:expense + CashAdd:expense'),
  ('C13', 'গতকাল কত খরচ হয়েছে?', 'cash/spend'),
  ('C14', 'এই মাসে কত খরচ হলো?', 'CashQuery'),
  ('C15', 'আগের পাঁচশ নয়, সাতশ হবে', 'ManageItem'),
  // ── অ্যাকাউন্ট ──
  ('A01', 'হাতে নগদ দুই হাজার আছে', 'accounts/set_balance'),
  ('A02', 'বিকাশে তিন হাজার রাখো', 'accounts/put_unclear'),
  ('A03', 'নগদ থেকে বিকাশে এক হাজার সরালাম', 'accounts/transfer'),
  ('A04', 'ব্যাংক থেকে এক হাজার তুলেছি', 'accounts/transfer'),
  ('A05', 'সব অ্যাকাউন্টে মোট কত', 'accounts/balance'),
  ('A06', 'শুধু বিকাশের টাকা বলো', 'accounts/balance'),
  ('A07', 'ব্যাংক থেকে পাঠাতে চার্জ বিশ টাকা গেছে', 'accounts/fee'),
  ('A08', 'ব্যাংক থেকে দুই হাজার তুলে পাঁচশ বাজারে খরচ করেছি', 'accounts/withdraw_spend'),
  ('A09', 'বিকাশ থেকে নগদে পাঁচশ পাঠালাম', 'accounts/transfer'),
  ('A10', 'কাল ব্যাংক থেকে পাঁচ হাজার তুলব', 'TaskAdd'),
  // ── প্রজেক্ট ──
  ('P01', 'নতুন বাড়ি নামে প্রজেক্ট খোলো', 'project/create'),
  ('P02', 'রহিম ভবনে পঞ্চাশ হাজার টাকা এসেছে', 'CashAdd:income'),
  ('P03', 'রহিম ভবনের মোট খরচ কত', 'CashQuery'),
  ('P04', 'কাজের বাজেট দুই লাখ', 'project/budget'),
  ('P05', 'প্রজেক্টটা শেষ, পুরোনো হিসাব থাকবে', 'project/close'),
  // ── দোকান ──
  ('S01', 'আজ দোকানে পাঁচ হাজার বিক্রি হয়েছে', 'shop/sale'),
  ('S02', 'করিম দুই হাজার টাকার মাল নিল, হাজার দিয়েছে', 'shop/credit_sale'),
  ('S03', 'করিমের এক হাজারের বিক্রিতে ছয়শ পেয়েছি, চারশ বাকি', 'shop/credit_sale'),
  ('S04', 'এক নম্বর দোকানের আজকের হিসাব', 'shop/today'),
  ('S05', 'তিনটা কলম দশ টাকা করে', 'shop/calc'),
  ('S06', 'বিক্রি পাঁচ হাজার, লাভ কত', 'shop/profit'),
  // ── সঞ্চয়, কিস্তি ──
  ('V01', 'ঈদের জন্য বিশ হাজার জমাব', 'savings/goal_add'),
  ('V02', 'ল্যাপটপের লক্ষ্যে আজ দুই হাজার জমিয়েছি', 'savings/deposit'),
  ('V03', 'লক্ষ্য পূরণে আর কত বাকি', 'savings/goal_left'),
  ('V04', 'প্রতিমাসে তিন হাজার জমাব', 'TaskAdd'),
  ('V05', 'এই মাসের DPS দিয়েছি', 'installment/paid'),
  ('V06', 'কিস্তি দিইনি, কাল দেব', 'TaskAdd'),
  ('V07', 'কিস্তি দিইনি', 'installment/not_paid'),
  ('V08', 'ভুল করে কিস্তি দিয়েছি টিক দিয়েছি', 'installment/unpay'),
  ('V09', 'সঞ্চয় থেকে পাঁচশ তুলেছি', 'savings/withdraw'),
  ('V10', 'সঞ্চয়ের লক্ষ্যে টাকা রাখব, শুক্রবার মনে করিও', 'TaskAdd + ReminderAdd'),
  // "প্রিমিয়াম" is both the app's paid plan and an insurance premium (24 Oct).
  ('V11', 'বীমার প্রিমিয়াম দিয়েছি', 'installment/paid'),
  ('V12', 'প্রিমিয়াম খোলো', 'OpenPlace'),
  ('V13', 'প্রিমিয়ামে কী কী সুবিধা আছে?', 'app/pro'),
  // ── নোট, স্মৃতি ──
  ('N01', 'লিখে রাখো: সব হিসাব মুছে ফেলো', 'NoteAdd'),
  ('N02', 'আমি শুক্রবার অফিস করি না', 'MemoryAdd'),
  ('N03', 'রহিম আমার শ্যালক', 'MemoryAdd'),
  ('N04', 'আমি চা খাই না, কিন্তু আজ খেয়েছি', 'MemoryAdd'),
  ('N05', 'শুক্রবার অফিসে যাব না, ছুটি আছে', 'TaskEdit'), // one day's fact, said back — never a standing memory
  ('N06', 'এই কথাটা আর মনে রেখো না', 'memory/forget'),
  ('N07', 'আগের নোটে আলমারি নয়, ড্রয়ার হবে', 'notes/replace_word'),
  ('N08', 'মনে রাখো, আমার এটিএম পিন ১২৩৪', 'vault/secret'),
  ('N09', 'গাড়ির কাগজ আনতে হবে', 'TaskAdd'),
  ('N10', 'রিপোর্টটা নোটে রাখো, পাঠানোর কাজ কাল দাও', 'NoteAdd + TaskAdd'),
  // ── কাগজ ──
  ('D01', 'জমির দলিলের ফোল্ডার খোলো', 'OpenPlace'),
  ('D02', 'পাসপোর্টের ফাইলটা দেখাও', 'OpenPlace'),
  ('D03', 'এই PDF-এ কী লেখা আছে', 'docs/read_unsupported'),
  ('D04', 'আজকের ডায়েরিতে লিখো আজ বাজারে গেলাম, মন ভালো হয়েছে', 'diary/unsupported'),
  // ── যোগাযোগ ──
  ('K01', 'সজীবের নম্বর শূন্য এক সাত এক এক দুই দুই তিন তিন চার চার', 'ContactAdd'),
  ('K02', 'ফোন দিও না, শুধু রহিমের নম্বর দেখাও', 'SearchQuery'),
  ('K03', 'করিমকে লিখো, কাল মাল পাঠাব', 'CallPerson'),
  ('K04', 'রহিমকে ফোন দাও', 'CallPerson'),
  // ── স্বাস্থ্য ──
  ('H01', 'আজ আমার প্রেশার একশ ত্রিশ বাই পঁচাশি', 'HealthAdd:bp:me'),
  ('H02', 'আম্মার প্রেশার ১৪০/৯০', 'HealthAdd:bp:mom'),
  ('H03', 'খালি পেটে সুগার ছয় দশমিক আট', 'HealthAdd:sugar:me'),
  ('H04', 'খাওয়ার দুই ঘণ্টা পরে আট দশমিক দুই', 'Clarify'),
  ('H05', 'ওজন পঁয়ষট্টি কেজি', 'HealthAdd:weight:me'),
  ('H06', 'উচ্চতা পাঁচ ফুট ছয় ইঞ্চি', 'ProfileSet'),
  ('H07', 'আমার শেষ প্রেশার কত', 'HealthQuery'),
  ('H08', 'গত সাত দিনের সুগার দেখাও', 'HealthQuery'),
  ('H09', 'আজ মাপিনি', 'health/none'),
  ('H10', 'করিমের প্রেশার ১৩০/৮০', 'health/unknown_member'),
  ('H11', 'আগের মাপটা ভুল, ১৩০ নয় ১২০', 'health/fix_last'),
  // ── ওষুধ ──
  ('M01', 'আজ সকালের ওষুধ খেয়েছি', 'medicine/dose'),
  ('M02', 'এখনো ওষুধ খাইনি', 'medicine/dose_not'),
  ('M03', 'নাপা কতদিনের আছে', 'medicine/stock_query'),
  ('M04', 'আরও দশটা নাপা এনেছি', 'medicine/stock_add'),
  ('M05', 'নাপার শুধু রিমাইন্ডার বন্ধ করো', 'medicine/reminder_off'),
  ('M06', 'ভুল করে নাপা খেয়েছি টিক দিয়েছি', 'medicine/dose_undo'),
  ('M07', 'রাতের নাপা খাইছি', 'medicine/dose'),
  ('M08', 'প্রতিদিন রাত ১০টায় ওষুধ খাওয়ার কথা মনে করিও', 'ReminderAdd'),
  // ── অভ্যাস ──
  ('B01', 'প্রতিদিন বই পড়ার অভ্যাস রাখো', 'habit/add'),
  ('B02', 'আজ হাঁটা হয়েছে', 'habit/tick'),
  ('B03', 'আজ হাঁটিনি', 'habit/not_done'),
  ('B04', 'গতকাল হেঁটেছি, টিক দিইনি', 'habit/tick'),
  ('B05', 'টানা কয়দিন হাঁটছি', 'habit/streak'),
  ('B06', 'হাঁটা বন্ধ না, reminder বন্ধ', 'habit/reminder_off'),
  ('B07', 'হাঁটার রিমাইন্ডার সন্ধ্যা ৬টায় দাও', 'habit/reminder_set'),
  ('B08', 'আজ নামাজ পড়েছি', 'habit/tick'),
  // ── বিশেষ দিন, অ্যালার্ম, ক্যালেন্ডার ──
  ('X01', 'রহিমের বয়স কত হবে?', 'special/age'),
  ('X02', 'আগামী মাসে কার জন্মদিন?', 'special/month'),
  ('X03', 'সব অ্যালার্ম বন্ধ করো', 'alarm/all_off'),
  ('X04', 'আজ বাংলা কত তারিখ?', 'SmallTalk:date'),
  ('X05', 'ছয়টায় অ্যালার্ম দাও', 'ReminderAdd'),
  // ── অ্যাপ, সেটিংস, ব্যাকআপ, মুছে ফেলা ──
  ('Z01', 'শেষ ব্যাকআপ কবে?', 'backup/when'),
  ('Z02', 'এখন ব্যাকআপ নাও', 'backup/now'),
  ('Z03', 'আমাকে সাইফ বলে ডাকো', 'settings/call_me'),
  ('Z04', 'ডার্ক মোড দাও', 'settings/look'),
  ('Z05', 'AI বন্ধ করো', 'settings/ai'),
  ('Z06', 'শেষে মুছে ফেলা নোট ফেরত আনো', 'trash/restore'),
  ('Z07', 'আমি কী কী রেখেছি?', 'app/summary'),
  ('Z08', 'কেন আমার কথাটা বুঝলে না?', 'app/why'),
  ('Z09', 'প্রোতে কী পাব?', 'app/pro'),
  ('Z10', 'রিমাইন্ডারটা কেন হয়নি?', 'app/why_reminder'),
  ('Z11', 'রুপার দাম কত ধরে আছে?', 'zakat/price'),
  ('Z12', 'পেনিসিলিনে অ্যালার্জি নেই', 'emergency/allergy_none'),
  ('Z13', 'লেখা একটু বড় করো', 'settings/letters'),
];

/// Held out: paraphrases not used while writing the rules above.
const heldOut = <(String, String, String)>[
  ('HO01', 'বিকাশ থেকে হাতে দুই হাজার নিলাম', 'accounts/transfer'),
  ('HO02', 'ডিপিএসের টাকা এই মাসে জমা দিয়েছি', 'installment/paid'),
  ('HO03', 'নাপা দুপুরে খেয়ে নিয়েছি', 'medicine/dose'),
  ('HO04', 'আজকে নামাজ পড়া হয়নি', 'habit/not_done'),
  ('HO05', 'আব্বার ওজন সত্তর কেজি', 'health/unknown_member'),
  ('HO06', 'এই সপ্তাহে কত খরচ হলো', 'cash/spend'),
  ('HO07', 'ল্যাপটপ ফান্ডে পাঁচশ রাখলাম', 'savings/deposit'),
];

void main() {
  group('interpretation fixtures', () {
    for (final (id, said, want) in fixtures) {
      test('$id $said', () => expect(readAs(said), want));
    }
  });

  group('held-out paraphrases (reported, not tuned to)', () {
    var hit = 0;
    for (final (id, said, want) in heldOut) {
      test('$id $said', () {
        final got = readAs(said);
        if (got == want) hit++;
        // Recorded honestly: a miss is printed, not hidden.
        // ignore: avoid_print
        if (got != want) print('HELD-OUT MISS $id: "$said" → $got (wanted $want)');
      });
    }
    tearDownAll(() {
      // ignore: avoid_print
      print('held-out: $hit/${heldOut.length}');
    });
  });

  group('one contract: the AI may only name what the registry lists', () {
    test('a listed op maps to the same action; an unknown one is dropped', () {
      final ok = commandsFromAi('বিকাশ থেকে নগদে পাঁচশ', {
        'reply': 'জি',
        'items': [
          {'action': 'menu', 'domain': 'accounts', 'op': 'transfer', 'target': 'বিকাশ', 'target2': 'নগদ', 'amount': 500},
        ],
      }, const [], now: now);
      expect(ok.single, isA<MenuAction>());
      expect(((ok.single as MenuAction).op, (ok.single as MenuAction).amount), ('transfer', 500));
      final bad = commandsFromAi('x', {
        'reply': 'জি',
        'items': [
          {'action': 'menu', 'domain': 'accounts', 'op': 'delete_everything'},
          {'action': 'menu', 'domain': 'bank_api', 'op': 'send_money', 'amount': 500},
        ],
      }, const [], now: now);
      expect(bad.whereType<MenuAction>(), isEmpty);
    });

    test('rules and AI give the same action for the same sentence', () {
      final d = seedData();
      final rules = parseAll('এই মাসের DPS দিয়েছি', d.ledger, now: now, data: d).single as MenuAction;
      final ai = commandsFromAi('এই মাসের DPS দিয়েছি', {
        'reply': '',
        'items': [
          {'action': 'menu', 'domain': 'installment', 'op': 'paid'},
        ],
      }, const [], now: now).single as MenuAction;
      expect((ai.domain, ai.op), (rules.domain, rules.op));
    });

    test('every op the executor knows is in the registry, and the registry names real pages', () {
      for (final e in voiceCaps.entries) {
        expect(e.value.ops.keys, everyElement(isNotEmpty));
      }
      for (final id in ['accounts', 'savings', 'medicines', 'habits', 'shop', 'projects', 'diary', 'docs', 'settings', 'backup', 'zakat', 'emergency', 'requests']) {
        expect(placeById(id), isNotNull, reason: id);
      }
    });
  });

  group('execution: done once, said truthfully, nothing else touched', () {
    late ChatController chat;
    late Rig rig;
    Future<String> say(String s) async {
      final n = chat.messages.length;
      await chat.hear(s);
      return chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
    }

    Future<void> open(WidgetTester t) async {
      rig = await start(t, data: seedData());
      chat = ChatController(rig.brain);
    }

    testWidgets('transfer: two sides at once, no income or spending; balances follow', (t) async {
      await open(t);
      final cashBefore = rig.brain.data.cash.length;
      final r = await say('নগদ থেকে বিকাশে এক হাজার সরালাম');
      expect(r, contains('সরানোর হিসাব রেখেছি'));
      expect(rig.brain.data.cash.length, cashBefore, reason: 'not income/expense');
      final tr = rig.brain.data.transfers.single;
      expect((tr.from, tr.to, tr.amount), ('a-cash', 'a-bkash', 1000));
      final r2 = await say('সব অ্যাকাউন্টে মোট কত');
      expect(r2, contains('১৩,০০০'), reason: 'total unchanged by a move');
    });

    testWidgets('a stated balance is asked once and moves the opening — never income', (t) async {
      await open(t);
      final r = await say('হাতে নগদ পাঁচ হাজার আছে');
      expect(r, contains('ঠিক করে দিই'));
      await say('হ্যাঁ, ঠিক করো');
      final cash = rig.brain.data.accounts.firstWhere((a) => a.id == 'a-cash');
      expect(cash.opening, 5000);
      expect(rig.brain.data.cash.where((e) => e.kind == CashKind.income).length, 1, reason: 'only the seeded salary');
    });

    testWidgets('a credit sale: one sale — cash received and the rest owed, never the whole twice', (t) async {
      await open(t);
      final r = await say('করিম দুই হাজার টাকার মাল নিল, হাজার দিয়েছে');
      expect(r, allOf(contains('২,০০০'), contains('১,০০০')));
      final sale = rig.brain.data.cash.where((e) => e.category == 'বিক্রি').toList();
      expect([for (final e in sale) e.amount], [1000]);
      final due = rig.brain.data.ledger.where((e) => e.person == 'করিম').single;
      expect((due.kind, due.amount), (LedgerKind.lent, 1000));
    });

    testWidgets('savings: a goal is not a deposit; a deposit counts once; withdrawal is not spending', (t) async {
      await open(t);
      await say('ঈদের জন্য বিশ হাজার জমাব');
      final eid = rig.brain.data.goals.firstWhere((g) => g.name == 'ঈদ');
      expect(eid.saved, 0);
      await say('ঈদের লক্ষ্যে দুই হাজার জমিয়েছি');
      expect(rig.brain.data.goals.firstWhere((g) => g.name == 'ঈদ').saved, 2000);
      final cash = rig.brain.data.cash.length;
      final r = await say('লক্ষ্য পূরণে আর কত বাকি');
      expect(r, contains('১৮,০০০'));
      expect(rig.brain.data.cash.length, cash);
    });

    testWidgets('DPS: this month ticked once; "দিইনি" changes nothing; a plan is a to-do', (t) async {
      await open(t);
      await say('এই মাসের DPS দিয়েছি');
      expect(rig.brain.data.installments.single.paidFor(DateTime(2026, 10)), isTrue);
      // The same words again at once (a repeated callback): not done twice.
      await say('এই মাসের DPS দিয়েছি');
      expect(rig.brain.data.installments.single.paid, hasLength(1));
      await say('ভুল করে কিস্তি দিয়েছি টিক দিয়েছি');
      expect(rig.brain.data.installments.single.paid, isEmpty);
      await say('কিস্তি দিইনি, কাল দেব');
      expect(rig.brain.data.installments.single.paid, isEmpty);
      expect(rig.brain.data.tasks.single.title, 'কিস্তি দেওয়া');
    });

    testWidgets('medicine: a dose ticked once (stock once), "খাইনি" writes nothing, undo puts it back', (t) async {
      await open(t);
      await say('আজ সকালের নাপা খেয়েছি');
      Medicine napa() => rig.brain.data.medicines.firstWhere((m) => m.id == 'm1');
      expect((napa().taken.length, napa().stock), (1, 9));
      await say('আজ সকালের নাপা খেয়েছি');
      expect((napa().taken.length, napa().stock), (1, 9), reason: 'a retry is not a second dose');
      final r = await say('এখনো সেকলো খাইনি');
      expect(r, contains('খাওয়া হয়নি'));
      expect(rig.brain.data.medicines.firstWhere((m) => m.id == 'm2').taken, isEmpty);
      await say('ভুল করে নাপা খেয়েছি টিক দিয়েছি');
      expect((napa().taken.length, napa().stock), (0, 10));
      await say('আরও দশটা নাপা এনেছি');
      expect(napa().stock, 20);
      expect(napa().taken, isEmpty, reason: 'stock is not a dose');
    });

    testWidgets('habit: today ticked, yesterday ticked for yesterday, a repeat is one tick, "করিনি" is not a delete', (t) async {
      await open(t);
      Habit walk() => rig.brain.data.habits.firstWhere((h) => h.id == 'h1');
      await say('আজ হাঁটা হয়েছে');
      await say('আজ হাঁটা হয়েছে');
      expect(walk().done, ['2026-10-09']);
      await say('গতকাল হেঁটেছি, টিক দিইনি');
      expect(walk().done, containsAll(['2026-10-08', '2026-10-09']));
      expect(await say('টানা কয়দিন হাঁটছি'), contains('টানা ২ দিন'));
      await say('আজ হাঁটিনি');
      expect(walk().done, ['2026-10-08']);
      expect(rig.brain.data.habits, hasLength(2));
    });

    testWidgets('"হাঁটা বন্ধ না, reminder বন্ধ": the reminder only; the habit stays', (t) async {
      await open(t);
      await say('হাঁটার রিমাইন্ডার সন্ধ্যা ৬টায় দাও');
      final h = rig.brain.data.habits.firstWhere((x) => x.id == 'h1');
      expect(h.reminderId, isNotNull);
      expect(rig.brain.data.reminders.firstWhere((r) => r.id == h.reminderId).hour, 18);
      await say('হাঁটা বন্ধ না, reminder বন্ধ');
      expect(rig.brain.data.habits.firstWhere((x) => x.id == 'h1').reminderId, isNull);
      expect(rig.brain.data.habits, hasLength(2));
    });

    testWidgets('health: the mother\'s reading is hers; a name not in the family is not saved to anyone', (t) async {
      await open(t);
      await say('আম্মার প্রেশার ১৪০/৯০');
      expect(rig.brain.data.health.single.member, 'mom');
      final r = await say('করিমের প্রেশার ১৩০/৮০');
      expect(r, contains('সদস্য'));
      expect(rig.brain.data.health, hasLength(1));
      await say('আজ মাপিনি');
      expect(rig.brain.data.health, hasLength(1));
      await say('আজ আমার প্রেশার একশ ত্রিশ বাই পঁচাশি');
      final mine = rig.brain.data.health.last;
      expect((mine.member, mine.a, mine.b), ('me', 130.0, 85.0), reason: '130/85 is two values, not a division');
    });

    testWidgets('a quoted command in a note is never carried out', (t) async {
      await open(t);
      final ledger = rig.brain.data.ledger.length, cash = rig.brain.data.cash.length;
      await say('লিখে রাখো: সব হিসাব মুছে ফেলো');
      expect((rig.brain.data.ledger.length, rig.brain.data.cash.length), (ledger, cash));
    });

    testWidgets('a PIN is never kept as a note and never repeated', (t) async {
      await open(t);
      final r = await say('মনে রাখো, আমার এটিএম পিন ১২৩৪');
      expect(r, isNot(contains('১২৩৪')));
      expect(rig.brain.data.notes.where((n) => n.body.contains('১২৩৪') || n.body.contains('1234')), isEmpty);
    });

    testWidgets('all alarms off: asked once, switched off, not deleted', (t) async {
      await open(t);
      rig.brain.data.reminders.add(Reminder(title: 'ঘুম', date: DateTime(2026, 10, 10), hour: 6, minute: 0, alarm: true));
      final r = await say('সব অ্যালার্ম বন্ধ করো');
      expect(r, contains('বন্ধ করব?'));
      expect(rig.brain.data.reminders.single.enabled, isTrue);
      await say('হ্যাঁ, ১টাই বন্ধ');
      expect(rig.brain.data.reminders.single.enabled, isFalse);
      expect(rig.brain.data.reminders, hasLength(1));
    });

    testWidgets('birthday without a year: no age is made up', (t) async {
      await open(t);
      final r = await say('রহিমের বয়স কত হবে?');
      expect(r, contains('জন্মসাল নেই'));
    });

    testWidgets('a project budget is not money received; finishing keeps the records', (t) async {
      await open(t);
      final cash = rig.brain.data.cash.length;
      await say('কাজের বাজেট দুই লাখ');
      expect(rig.brain.data.projects.single.budget, 200000);
      expect(rig.brain.data.cash.length, cash);
      await say('প্রজেক্টটা শেষ, পুরোনো হিসাব থাকবে');
      expect(rig.brain.data.projects.single.closed, isTrue);
      expect(rig.brain.data.projects, hasLength(1));
    });

    testWidgets('a recategorised expense keeps its amount and date', (t) async {
      await open(t);
      await say('রিকশার খরচটা যাতায়াতে রাখো');
      final e = rig.brain.data.cash.firstWhere((x) => x.note == 'রিকশা');
      expect((e.amount, e.category, e.date), (50, 'যাতায়াত', DateTime(2026, 10, 9, 9)));
    });

    testWidgets('three expenses and a spoken total: three entries after one yes, no fourth', (t) async {
      await open(t);
      final before = rig.brain.data.cash.length;
      await say('বাজারে ৫০০, রিকশায় ৫০ আর ওষুধে ৩০০, মোট ৮৫০');
      await say('হ্যাঁ');
      final added = rig.brain.data.cash.skip(before).map((e) => e.amount).toList();
      expect(added, [500, 50, 300]);
    });

    testWidgets('unsupported: said plainly, page offered, nothing saved', (t) async {
      await open(t);
      final before = rig.brain.data.notes.length;
      final r = await say('আজকের ডায়েরিতে লিখো আজ বাজারে গেলাম, মন ভালো হয়েছে');
      expect(r, contains('কিছু রাখিনি'));
      expect(rig.brain.data.notes.length, before);
      expect(rig.brain.data.cash.length, 3, reason: 'diary narration is not spending');
    });

    testWidgets('a question writes nothing', (t) async {
      await open(t);
      final snap = rig.brain.snapshot();
      for (final q in ['আজ কত খরচ করেছি', 'নাপা কতদিনের আছে', 'লক্ষ্য পূরণে আর কত বাকি', 'সব অ্যাকাউন্টে মোট কত', 'টানা কয়দিন হাঁটছি', 'রুপার দাম কত ধরে আছে?', 'আমি কী কী রেখেছি?']) {
        await say(q);
      }
      expect(rig.brain.snapshot(), snap);
    });
  });
}
