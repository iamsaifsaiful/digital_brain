// Carrying out a [MenuAction] (logic/menus.dart): find the saved record by
// its id from the user's own names, check what the menu allows, do it once,
// and say only what really happened — saved, changed, asked, or "this cannot
// be done by voice" with the page offered. Nothing here is decided by the AI.
part of 'chat.dart';

extension _MenuChat on ChatController {
  /// The record named in [said] among [names]: exact, then contained, then
  /// by stem. Null when none, or more than one equally (the caller asks).
  int? _pickNamed(String said, List<String> names) {
    final s = fold(said.trim().toLowerCase());
    if (s.isEmpty) return names.length == 1 ? 0 : null;
    final exact = [for (var i = 0; i < names.length; i++) if (fold(names[i].toLowerCase()) == s) i];
    if (exact.length == 1) return exact.single;
    final part = [for (var i = 0; i < names.length; i++) if (fold(names[i].toLowerCase()).contains(s) || s.contains(fold(names[i].toLowerCase()))) i];
    if (part.length == 1) return part.single;
    return null;
  }

  MoneyAccount? _account(String said) {
    final accts = brain.data.accounts;
    if (accts.isEmpty) return null;
    final i = _pickNamed(said, [for (final a in accts) a.name]);
    if (i != null) return accts[i];
    // By kind: "বিকাশ", "ব্যাংক", "হাতে/নগদ".
    final kinds = <AccountKind>[
      if (RegExp(fold('(?:বিকাশ|bkash)')).hasMatch(fold(said))) AccountKind.bkash,
      if (RegExp(fold('(?:রকেট|rocket)')).hasMatch(fold(said))) AccountKind.rocket,
      if (RegExp(fold('(?:ব্যাংক|bank)')).hasMatch(fold(said))) AccountKind.bank,
      if (RegExp(fold('(?:নগদ|হাত|ক্যাশ|cash)')).hasMatch(fold(said))) ...[AccountKind.cash, AccountKind.nagad],
    ];
    for (final k in kinds) {
      final of = accts.where((a) => a.kind == k).toList();
      if (of.length == 1) return of.single;
    }
    return null;
  }

  List<ChatLink> _pageLink(String page) {
    final p = placeById(page);
    return [ChatLink(LinkKind.page, trf('খুলুন: {0}', [tr(p?.title ?? page)]), page: page)];
  }

  /// What cannot be done by voice there: said plainly, nothing saved.
  void _unsupported(String page, String what, List<String> out) {
    final p = placeById(page);
    _say(out, trf('{0} — কথায় এটা এখনো করা যায় না, তাই কিছু রাখিনি। {1} পাতায় নিজে করে নিতে পারেন।', [what, tr(p?.title ?? page)]), links: _pageLink(page));
  }

  Future<void> _menu(MenuAction c, List<String> out) async {
    final d = brain.data;
    final snap = brain.snapshot();
    Trace.log('understood', 'menu', {'domain': c.domain, 'op': c.op});
    switch ((c.domain, c.op)) {
      // ── Accounts ──
      case ('accounts', 'balance'):
        if (d.accounts.isEmpty) {
          _say(out, tr('কোনো অ্যাকাউন্ট রাখা নেই। অ্যাকাউন্ট পাতায় হাতের টাকা, বিকাশ বা ব্যাংক যোগ করলে কোথায় কত আছে বলতে পারব।'), links: _pageLink('accounts'));
          return;
        }
        if (c.target.isNotEmpty) {
          final a = _account(c.target);
          if (a == null) {
            _say(out, trf('“{0}” নামে কোনো অ্যাকাউন্ট নেই।', [c.target]), links: _pageLink('accounts'));
            return;
          }
          _say(out, trf('অ্যাপের হিসাবে {0}-এ এখন {1} টাকা।', [accountLabel(a), bnNumber(accountBalance(d, a))]), links: _pageLink('accounts'));
          return;
        }
        final lines = [for (final a in d.accounts) '${accountLabel(a)}: ${bnNumber(accountBalance(d, a))} ${tr('টাকা')}'];
        _say(out, trf('সব অ্যাকাউন্ট মিলিয়ে {0} টাকা ({1}টা অ্যাকাউন্ট)।', [bnNumber(totalBalance(d)), bnDigits(d.accounts.length)]), facts: lines, links: _pageLink('accounts'));
      case ('accounts', 'transfer'):
        final from = _account(c.target), to = _account(c.target2);
        if (from == null || to == null) {
          final missing = from == null ? c.target : c.target2;
          _say(out, trf('“{0}” নামে কোনো অ্যাকাউন্ট নেই, তাই কিছু লিখিনি। অ্যাকাউন্ট পাতায় যোগ করে আবার বলুন।', [missing]), links: _pageLink('accounts'));
          return;
        }
        if (from.id == to.id) {
          _say(out, tr('একই অ্যাকাউন্ট থেকে একই অ্যাকাউন্টে — কোথা থেকে কোথায় সরালেন, আরেকবার বলুন।'));
          return;
        }
        await brain.saveTransfer(Transfer(from: from.id, to: to.id, amount: c.amount, fee: c.amount2, date: _now, note: tr('কথায় বলা')));
        _actions++;
        final fee = c.amount2 > 0 ? trf(' চার্জ {0} টাকা আলাদা — {1} থেকে কেটেছে।', [bnNumber(c.amount2), accountLabel(from)]) : '';
        _say(out, trf('{0} থেকে {1}-এ {2} টাকা সরানোর হিসাব রেখেছি।{3} এটা আয় বা খরচ নয়।', [accountLabel(from), accountLabel(to), bnNumber(c.amount), fee]), links: _pageLink('accounts'));
        _offerUndo(snap);
      case ('accounts', 'withdraw_spend'):
        final from = _account(c.target);
        final cash = d.accounts.where((x) => x.kind == AccountKind.cash).firstOrNull;
        if (from == null || cash == null || from.id == cash.id) {
          _say(out, trf('“{0}” বা হাতের টাকার অ্যাকাউন্ট নেই, তাই কিছু লিখিনি। অ্যাকাউন্ট পাতায় যোগ করে আবার বলুন।', [c.target]), links: _pageLink('accounts'));
          return;
        }
        await brain.saveTransfer(Transfer(from: from.id, to: cash.id, amount: c.amount, date: _now, note: tr('কথায় বলা')));
        final cat = categoryFor(normalize('${c.text} খরচ'), CashKind.expense);
        await brain.saveCash(CashEntry(kind: CashKind.expense, amount: c.amount2, category: cat, note: c.text, date: _now, accountId: cash.id));
        _actions++;
        _say(out, trf('দুটো লিখেছি: {0} থেকে {1}-এ {2} টাকা তোলা (আয় নয়), আর {1} থেকে {3} খাতে {4} টাকা খরচ।', [accountLabel(from), accountLabel(cash), bnNumber(c.amount), cat, bnNumber(c.amount2)]),
            links: _pageLink('accounts'));
        _offerUndo(snap);
      case ('accounts', 'fee'):
        final from = _account(c.target);
        await brain.saveCash(CashEntry(kind: CashKind.expense, amount: c.amount, category: tr('চার্জ'), note: tr('কথায় বলা'), date: _now, accountId: from?.id));
        _actions++;
        _say(out, trf('চার্জ {0} টাকা খরচ হিসেবে লিখেছি{1}।', [bnNumber(c.amount), from == null ? '' : trf(' ({0} থেকে)', [accountLabel(from)])]), links: _pageLink('accounts'));
        _offerUndo(snap);
      case ('accounts', 'set_balance'):
        final a = _account(c.target);
        if (a == null) {
          _say(out, trf('“{0}” নামে কোনো অ্যাকাউন্ট নেই, তাই কিছু লিখিনি।', [c.target]), links: _pageLink('accounts'));
          return;
        }
        final now = accountBalance(d, a);
        if (now == c.amount) {
          _say(out, trf('{0}-এ হিসাবেও {1} টাকাই আছে — কিছু বদলাতে হলো না।', [accountLabel(a), bnNumber(c.amount)]));
          return;
        }
        // A balance stated as it stands: the starting figure moves, never income.
        _clarifyOptions = [
          (tr('হ্যাঁ, ঠিক করো'), MenuAction(c.transcript, domain: 'accounts', op: 'set_balance_yes', target: a.id, amount: c.amount)),
          (tr('না'), SmallTalk(c.transcript, kind: Talk.cancelled)),
        ];
        _ask(out, trf('হিসাবে {0}-এ {1} টাকা আছে। এখন {2} টাকা ধরে ঠিক করে দিই? (আয় বা খরচ হিসেবে লেখা হবে না)', [accountLabel(a), bnNumber(now), bnNumber(c.amount)]), ChatWait.clarify,
            choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
      case ('accounts', 'set_balance_yes'):
        final a = d.accounts.where((x) => x.id == c.target).firstOrNull;
        if (a == null) return;
        await brain.saveAccount(a.copyWith(opening: a.opening + c.amount - accountBalance(d, a)));
        _actions++;
        _say(out, trf('ঠিক আছে, {0}-এ এখন {1} টাকা ধরলাম।', [accountLabel(a), bnNumber(c.amount)]), links: _pageLink('accounts'));
        _offerUndo(snap);
      case ('accounts', 'put_unclear'):
        final a = _account(c.target);
        if (a == null) {
          _say(out, trf('“{0}” নামে কোনো অ্যাকাউন্ট নেই, তাই কিছু লিখিনি।', [c.target]), links: _pageLink('accounts'));
          return;
        }
        final cash = d.accounts.where((x) => x.kind == AccountKind.cash && x.id != a.id).firstOrNull;
        _clarifyOptions = [
          (trf('{0}-এ এখন মোট {1} আছে', [accountLabel(a), bnNumber(c.amount)]), MenuAction(c.transcript, domain: 'accounts', op: 'set_balance', target: c.target, amount: c.amount)),
          if (cash != null) (trf('{0} থেকে {1}-এ সরালাম', [accountLabel(cash), accountLabel(a)]), MenuAction(c.transcript, domain: 'accounts', op: 'transfer', target: cash.name, target2: a.name, amount: c.amount)),
        ];
        _ask(out, trf('{0} টাকা — কোনটা বোঝালেন?', [bnNumber(c.amount)]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);

      // ── Savings goals ──
      case ('savings', 'goal_add'):
        final name = c.target.trim();
        if (d.goals.any((g) => fold(g.name) == fold(name))) {
          _say(out, trf('“{0}” লক্ষ্য আগেই আছে।', [name]), links: _pageLink('savings'));
          return;
        }
        await brain.saveGoal(SavingsGoal(name: name, target: c.amount, createdAt: _now));
        _actions++;
        _say(out, trf('“{0}” — {1} টাকার সঞ্চয়ের লক্ষ্য রেখেছি। এখনো কিছু জমা হয়নি; জমালে বলবেন।', [name, bnNumber(c.amount)]), links: _pageLink('savings'));
        _offerUndo(snap);
      case ('savings', 'deposit' || 'withdraw'):
        final i = _pickNamed(c.target, [for (final g in d.goals) g.name]);
        if (d.goals.isEmpty || i == null) {
          _say(out, d.goals.isEmpty ? tr('কোনো সঞ্চয়ের লক্ষ্য রাখা নেই, তাই কিছু লিখিনি। আগে লক্ষ্য রাখুন — যেমন “ল্যাপটপের জন্য ৫০ হাজার জমাব”।') : tr('কোন লক্ষ্যে? নামটা বলে আরেকবার বলুন।'),
              links: _pageLink('savings'));
          return;
        }
        final g = d.goals[i];
        final out2 = c.op == 'withdraw';
        if (out2 && c.amount > g.saved) {
          _say(out, trf('“{0}”-এ জমা আছে {1} টাকা — {2} তোলা যায় না। কিছু বদলাইনি।', [g.name, bnNumber(g.saved), bnNumber(c.amount)]));
          return;
        }
        await brain.addDeposit(g, out2 ? -c.amount : c.amount);
        _actions++;
        final now2 = brain.data.goals.firstWhere((x) => x.id == g.id);
        final left = now2.target - now2.saved;
        _say(
            out,
            out2
                ? trf('“{0}” থেকে {1} টাকা তোলা লিখেছি (খরচ হিসেবে নয়)। এখন জমা {2} টাকা।', [g.name, bnNumber(c.amount), bnNumber(now2.saved)])
                : trf('“{0}” লক্ষ্যে {1} টাকা জমা লিখেছি। মোট জমা {2} টাকা{3}।', [g.name, bnNumber(c.amount), bnNumber(now2.saved), left > 0 ? trf('; আরও {0} টাকা বাকি', [bnNumber(left)]) : tr(' — লক্ষ্য পূরণ হয়েছে')]),
            links: _pageLink('savings'));
        _offerUndo(snap);
      case ('savings', 'goal_left'):
        if (d.goals.isEmpty) {
          _say(out, tr('কোনো সঞ্চয়ের লক্ষ্য রাখা নেই।'), links: _pageLink('savings'));
          return;
        }
        final i = c.target.isEmpty ? null : _pickNamed(c.target, [for (final g in d.goals) g.name]);
        final goals = i == null ? d.goals : [d.goals[i]];
        final lines = [
          for (final g in goals) trf('{0}: জমা {1}, লক্ষ্য {2}, বাকি {3} টাকা', [g.name, bnNumber(g.saved), bnNumber(g.target), bnNumber((g.target - g.saved).clamp(0, 1 << 40))]),
        ];
        _say(out, goals.length == 1 ? '${lines.single}।' : trf('{0}টা লক্ষ্য:', [bnDigits(goals.length)]), facts: goals.length == 1 ? const [] : lines, links: _pageLink('savings'));

      // ── Instalments ──
      case ('installment', 'paid' || 'unpay' || 'not_paid'):
        final list = d.installments;
        if (list.isEmpty) {
          _say(out, tr('কোনো কিস্তি বা DPS রাখা নেই, তাই কিছু লিখিনি।'), links: _pageLink('savings'));
          return;
        }
        final i = list.length == 1 ? 0 : _pickNamed(c.transcript, [for (final x in list) x.name]);
        if (i == null) {
          _say(out, trf('কোন কিস্তিটা? — {0}', [nameList([for (final x in list) x.name], unit: 'টা')]), links: _pageLink('savings'));
          return;
        }
        final inst = list[i];
        final month = c.day ?? DateTime(_now.year, _now.month);
        final label = '${monthName(month.month)} ${bnDigits(month.year)}';
        final paid = inst.paidFor(month);
        if (c.op == 'not_paid') {
          _say(out, paid ? trf('“{0}”-এর {1}-এর কিস্তি দেওয়া হিসেবে টিক দেওয়া আছে। ভুল হলে বলুন “ভুল করে কিস্তি দিয়েছি টিক দিয়েছি”।', [inst.name, label]) : trf('ঠিক আছে, “{0}”-এর {1}-এর কিস্তি বাকি হিসেবেই আছে।', [inst.name, label]));
          return;
        }
        if ((c.op == 'paid') == paid) {
          _say(out, paid ? trf('“{0}”-এর {1}-এর কিস্তি আগেই দেওয়া হিসেবে আছে।', [inst.name, label]) : trf('“{0}”-এর {1}-এর কিস্তি দেওয়া হিসেবে টিক দেওয়া ছিল না।', [inst.name, label]));
          return;
        }
        await brain.toggleInstallmentPaid(inst, month);
        _actions++;
        _say(out, c.op == 'paid' ? trf('“{0}”-এর {1}-এর কিস্তি ({2} টাকা) দেওয়া হিসেবে টিক দিয়েছি।', [inst.name, label, bnNumber(inst.amount)]) : trf('“{0}”-এর {1}-এর টিক তুলে দিয়েছি — বাকি হিসেবে আছে।', [inst.name, label]),
            links: _pageLink('savings'));
        _offerUndo(snap);

      // ── Lists "এগুলো" can then point at ──
      case ('medicine', 'list'):
        if (d.medicines.isEmpty) {
          _say(out, tr('ওষুধের তালিকায় কিছু নেই।'), links: _pageLink('medicines'));
          return;
        }
        _rememberSet('medicines', '', [for (final m in d.medicines) m.id], source: c.transcript);
        _say(out, trf('{0}টা ওষুধ:', [bnDigits(d.medicines.length)]), facts: [for (final m in d.medicines) '${m.name} — ${m.times.map((t) => bnTime(t ~/ 60, t % 60)).join(', ')}'], links: _pageLink('medicines'));
      case ('habit', 'list'):
        if (d.habits.isEmpty) {
          _say(out, tr('কোনো অভ্যাস রাখা নেই।'), links: _pageLink('habits'));
          return;
        }
        _rememberSet('habits', tr('আজকের'), [for (final h in d.habits) h.id], source: c.transcript);
        _say(out, trf('{0}টা অভ্যাস:', [bnDigits(d.habits.length)]), facts: [for (final h in d.habits) '${h.name} — ${h.doneOn(_now) ? tr('আজ হয়েছে') : tr('আজ বাকি')}'], links: _pageLink('habits'));
      case ('notes', 'read'):
        // By its words (title first); none said — the newest. Read as data.
        final ws = words(normalize(c.text)).where((x) => x.runes.length > 1).toList();
        int score(Note n) {
          final t = words(normalize(n.title)).toSet(), b = normalize(n.body);
          return ws.fold(0, (s, w) => s + (t.any((x) => x.startsWith(w) || w.startsWith(x)) ? 3 : (b.contains(w) ? 1 : 0)));
        }
        final ranked = [...d.notes]..sort((a, b) {
            final r = score(b).compareTo(score(a));
            return r != 0 ? r : b.updatedAt.compareTo(a.updatedAt);
          });
        final n = ranked.isEmpty || (ws.isNotEmpty && score(ranked.first) == 0) ? null : ranked.first;
        if (n == null) {
          _say(out, ws.isEmpty ? tr('কোনো নোট নেই।') : trf('“{0}”-এর কোনো নোট নেই।', [c.text]), links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
          return;
        }
        _rememberSet('notes', '', [n.id], source: c.transcript);
        _say(out, trf('নোটে লেখা আছে: {0}', [noteLine(n)]), links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
      case ('notes', 'list'):
        final w = fold(c.text.replaceAll(RegExp(fold(r'(?:ের|এর|র)$')), ''));
        final list = [for (final n in d.notes) if (w.isEmpty || fold(n.category).contains(w) || fold('${n.title} ${n.body}').contains(w)) n]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (list.isEmpty) {
          _say(out, w.isEmpty ? tr('কোনো নোট নেই।') : trf('“{0}”-এর কোনো নোট নেই।', [c.text]), links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
          return;
        }
        _rememberSet('notes', c.text.isEmpty ? '' : '${c.text}', [for (final n in list) n.id], source: c.transcript);
        _say(out, trf('{0}টা নোট:', [bnDigits(list.length)]), facts: [for (final n in list) noteLine(n)], links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
      case ('health', 'list'):
        final m = c.target.isEmpty ? null : memberCalled(d, c.target.replaceAll(RegExp(fold(r'(?:য়ের|ের|এর|র)$')), ''));
        if (c.target.isNotEmpty && m == null) {
          _say(out, trf('“{0}” নামে পরিবারের কোনো সদস্য রাখা নেই।', [c.target]), links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);
          return;
        }
        final who = m?.id ?? 'me';
        final logs = [for (final h in d.health) if (h.member == who) h]..sort((a, b) => b.at.compareTo(a.at));
        final shown = logs.take(c.amount <= 0 ? 5 : c.amount).toList();
        if (shown.isEmpty) {
          _say(out, tr('কোনো মাপ রাখা নেই।'), links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);
          return;
        }
        _rememberSet('health', m == null ? tr('আপনার') : possessive(m.relation.isNotEmpty ? m.relation : m.name), [for (final h in shown) h.id], matching: logs.length, shown: shown.length, source: c.transcript);
        _say(out, trf('শেষ {0}টা মাপ:', [bnDigits(shown.length)]), facts: [for (final h in shown) '${isEn ? h.kind.en : h.kind.bn}: ${readingText(h)} (${sayWhen(h.at, _now)})'], links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);

      // ── Medicines ──
      case ('medicine', _):
        await _medicine(c, out, snap);

      // ── Habits ──
      case ('habit', 'add'):
        final name = c.target.trim();
        if (d.habits.any((h) => fold(h.name) == fold(name))) {
          _say(out, trf('“{0}” অভ্যাস আগেই আছে।', [name]), links: _pageLink('habits'));
          return;
        }
        await brain.saveHabit(Habit(name: name, createdAt: _now));
        _actions++;
        _say(out, trf('“{0}” অভ্যাস যোগ করেছি। আজ করা হলে বলবেন — টিক দিয়ে দেব।', [name]), links: _pageLink('habits'));
        _offerUndo(snap);
      case ('habit', _):
        final i = _pickNamed(c.target, [for (final h in d.habits) h.name]);
        if (i == null) return;
        final h = d.habits[i];
        final day = c.day ?? dayOnly(_now);
        final when = sayWhen(day, _now, withTime: false);
        switch (c.op) {
          case 'tick':
            if (h.doneOn(day)) {
              _say(out, trf('“{0}” {1}-এর টিক আগেই দেওয়া আছে।', [h.name, when]));
              return;
            }
            await brain.toggleHabit(h, day);
            _actions++;
            final now2 = brain.data.habits.firstWhere((x) => x.id == h.id);
            final more = c.text == 'remind' ? trf(' রিমাইন্ডারের জন্য সময়সহ বলুন — যেমন “{0}ের রিমাইন্ডার সন্ধ্যা ৬টায় দাও”।', [h.name]) : '';
            _say(out, trf('“{0}” — {1}-এর টিক দিয়েছি। টানা {2} দিন।{3}', [h.name, when, bnDigits(now2.streak(_now)), more]), links: _pageLink('habits'));
            _offerUndo(snap);
          case 'not_done':
            if (h.doneOn(day)) {
              await brain.toggleHabit(h, day);
              _actions++;
              _say(out, trf('“{0}” — {1}-এর টিক তুলে দিয়েছি। অভ্যাসটা তালিকায় আছে।', [h.name, when]), links: _pageLink('habits'));
              _offerUndo(snap);
            } else {
              _say(out, trf('ঠিক আছে, “{0}” {1} টিক দেওয়া নেই — কিছু বদলাইনি।', [h.name, when]));
            }
          case 'streak':
            final n = h.streak(_now);
            _say(out, n == 0 ? trf('“{0}”-এ এখন টানা কোনো দিনের টিক নেই।', [h.name]) : trf('“{0}” — টানা {1} দিনের টিক আছে।', [h.name, bnDigits(n)]), links: _pageLink('habits'));
          case 'reminder_set':
            final t = c.time!;
            if (c.part == '?') {
              final r = ampmReadings(DateTime(_now.year, _now.month, _now.day, t ~/ 60, t % 60), _now);
              _clarifyOptions = [for (final x in r) (bnTime(x.hour, x.minute), MenuAction(c.transcript, domain: 'habit', op: 'reminder_set', target: c.target, time: x.hour * 60 + x.minute))];
              _ask(out, trf('{0}, নাকি {1}?', [bnTime(r[0].hour, r[0].minute), bnTime(r[1].hour, r[1].minute)]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
              return;
            }
            if (h.reminderId == null && !brain.canAddReminder) {
              _say(out, trf('“{0}” অভ্যাস আছে, তবে রিমাইন্ডার চালু হয়নি — ফ্রিতে একসাথে {1}টা রিমাইন্ডার রাখা যায়।', [h.name, bnDigits(freeReminders)]), links: _pageLink('pro'));
              return;
            }
            await brain.setHabitReminder(h, t);
            _actions++;
            final on = (await brain.services.notifier.health()).notificationsOn;
            _say(out, on ? trf('“{0}” — প্রতিদিন {1}-এ মনে করিয়ে দেব।', [h.name, bnTime(t ~/ 60, t % 60)]) : trf('“{0}”-এর রিমাইন্ডার {1}-এ রাখা হয়েছে, কিন্তু ফোনে অ্যাপের নোটিফিকেশন বন্ধ — তাই এখন বাজবে না।', [h.name, bnTime(t ~/ 60, t % 60)]),
                links: _pageLink('habits'));
            _offerUndo(snap);
          case 'reminder_off':
            if (h.reminderId == null) {
              _say(out, trf('“{0}”-এর কোনো রিমাইন্ডার ছিল না। অভ্যাসটা আছে।', [h.name]));
              return;
            }
            await brain.setHabitReminder(h, null);
            _actions++;
            _say(out, trf('“{0}”-এর রিমাইন্ডার বন্ধ করেছি; অভ্যাস আর তার টিক যেমন ছিল আছে।', [h.name]), links: _pageLink('habits'));
            _offerUndo(snap);
        }

      // ── People in the ধার-দেনা book ──
      case ('people', 'rename'):
        final key = personKey(c.target);
        final mine = [for (final e in d.ledger) if (personKey(e.person) == key) e];
        if (mine.isEmpty || c.text.trim().isEmpty) {
          _say(out, trf('“{0}” নামে লেনদেনের খাতায় কেউ নেই — কিছু বদলাইনি।', [c.target]));
          return;
        }
        final joined = d.ledger.any((e) => personKey(e.person) == personKey(c.text));
        for (final e in mine) {
          await brain.saveEntry(e.copyWith(person: c.text.trim()), guessPhone: false);
        }
        _actions++;
        final left = balanceOf(brain.data.ledger, c.text.trim());
        _say(
            out,
            trf('ঠিক আছে, “{0}”-এর নাম এখন “{1}” — {2}টা লেনদেন সহ।{3}{4}', [
              c.target,
              c.text.trim(),
              bnDigits(mine.length),
              joined ? tr(' এই নামে আগের হিসাবের সাথে এক হয়ে গেল।') : '',
              left == null ? '' : ' ${owesText(left.name, left.balance)}।',
            ]),
            links: [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(c.text.trim())]), person: c.text.trim())]);
        _offerUndo(snap);

      // ── What to keep in mind ──
      case ('memory', 'forget'):
        final mems = d.memories;
        if (mems.isEmpty) {
          _say(out, tr('আপনার সম্পর্কে মনে রাখা কোনো কথা নেই।'));
          return;
        }
        Memory? m;
        if (c.text.trim().isNotEmpty) {
          final i = _pickNamed(c.text, [for (final x in mems) x.text]);
          if (i != null) m = mems[i];
        } else {
          // "এই কথাটা": the one just kept, while it is fresh.
          final last = _lastSave;
          if (last != null && last.$1 is MemoryAdd && _now.difference(last.$3).inMinutes <= 10) {
            m = mems.where((x) => x.text == (last.$1 as MemoryAdd).text.trim()).firstOrNull;
          }
        }
        if (m == null) {
          _say(out, tr('কোন কথাটা ভুলে যাব? কথাটার কয়েকটা শব্দ বলুন — যেমন “শ্যালকের কথাটা আর মনে রেখো না”।'), links: [ChatLink(LinkKind.memory, tr('মনে রাখা কথা'))]);
          return;
        }
        await brain.deleteMemory(m.id);
        _actions++;
        _say(out, trf('ঠিক আছে, “{0}” — আর মনে রাখব না। (চ্যাটের লেখা যেমন ছিল আছে।)', [m.text]), links: [ChatLink(LinkKind.memory, tr('মনে রাখা কথা'))]);
        _offerUndo(snap);

      // ── Alarms ──
      case ('alarm', 'all_off'):
        final on = d.reminders.where((r) => r.alarm && r.enabled).toList();
        if (on.isEmpty) {
          _say(out, tr('চালু কোনো অ্যালার্ম নেই।'), links: _pageLink('alarms'));
          return;
        }
        _clarifyOptions = [
          (trf('হ্যাঁ, {0}টাই বন্ধ', [bnDigits(on.length)]), MenuAction(c.transcript, domain: 'alarm', op: 'all_off_yes')),
          (tr('না'), SmallTalk(c.transcript, kind: Talk.cancelled)),
        ];
        _ask(out, trf('{0}টা অ্যালার্ম চালু আছে — সবগুলো বন্ধ করব? (মুছব না, পরে আবার চালু করা যাবে)', [bnDigits(on.length)]), ChatWait.clarify,
            choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)], facts: [for (final r in on) '${bnTime(r.hour, r.minute)} — ${r.title}']);
      case ('alarm', 'all_off_yes'):
        var n = 0;
        for (final r in d.reminders.where((r) => r.alarm && r.enabled).toList()) {
          await brain.saveReminder(r.copyWith(enabled: false));
          n++;
        }
        _actions++;
        _say(out, trf('{0}টা অ্যালার্ম বন্ধ করেছি — মুছিনি।', [bnDigits(n)]), links: _pageLink('alarms'));
        _offerUndo(snap);

      // ── Notes ──
      case ('notes', 'replace_word'):
        final from = c.target.replaceAll(RegExp(fold(r'(?:ের|এর|র|ে|এ|তে)$')), '');
        final hit = [for (final x in d.notes) if (fold('${x.title} ${x.body}').contains(fold(from))) x]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (hit.isEmpty) {
          _say(out, trf('“{0}” লেখা কোনো নোট পাইনি, কিছু বদলাইনি।', [from]), links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
          return;
        }
        final n = hit.first;
        final to = c.text;
        String sw(String x) => x.replaceAll(RegExp('${RegExp.escape(fold(from))}\\S*'), to);
        final fixed = Note(id: n.id, title: sw(fold(n.title)), body: sw(fold(n.body)), category: n.category, updatedAt: _now, files: n.files);
        await brain.saveNote(fixed);
        _actions++;
        _say(out, trf('নোটটা বদলেছি — এখন: “{0}”।', [fixed.body.isEmpty ? fixed.title : fixed.body]), links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))]);
        _offerUndo(snap);

      // ── The bin ──
      case ('trash', 'restore'):
        final kind = _trashKind(c.target);
        final item = [for (final t in d.trash) if (kind == null || t.kind == kind) t].lastOrNull;
        if (item == null) {
          _say(out, kind == null ? tr('মুছে ফেলা কিছু নেই।') : trf('মুছে ফেলা কোনো {0} নেই।', [c.target]), links: _pageLink('settings'));
          return;
        }
        await brain.restoreTrash(item);
        _actions++;
        _say(out, trf('“{0}” ফেরত এনেছি।', [item.title]));
        _offerUndo(snap);

      // ── Backup ──
      case ('backup', 'when'):
        final drive = brain.lastDrive;
        final local = DateTime.tryParse(brain.text('last_backup'));
        final last = [drive, local].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
        _say(out, last == null ? tr('এই ফোনে কোনো ব্যাকআপের খবর নেই।') : trf('শেষ ব্যাকআপ: {0}{1}।', [sayWhen(last, _now), drive != null && drive == last ? tr(' (Google Drive-এ)') : '']), links: _pageLink('backup'));
      case ('backup', 'status'):
        final drive = brain.lastDrive;
        final local = DateTime.tryParse(brain.text('last_backup'));
        final last = [drive, local].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
        final lastText = last == null ? tr(' এখনো কোনো ব্যাকআপ হয়নি।') : trf(' শেষ ব্যাকআপ: {0}।', [sayWhen(last, _now)]);
        if (!brain.signedIn) {
          _say(out, tr('Google ব্যাকআপ চালু নেই — Google দিয়ে লগইন করা হয়নি। ব্যাকআপ পাতা থেকে লগইন করলে চালু হবে।') + lastText, links: _pageLink('backup'));
        } else if (!brain.driveOn) {
          _say(out, tr('Google-এ লগইন আছে, কিন্তু Drive-এ নিজে থেকে ব্যাকআপ বন্ধ।') + lastText, links: _pageLink('backup'));
        } else {
          _say(out, tr('Google ব্যাকআপ চালু আছে।') + lastText, links: _pageLink('backup'));
        }
      case ('backup', 'now'):
        if (!brain.signedIn) {
          _say(out, tr('ব্যাকআপ নিতে আগে Google দিয়ে লগইন করতে হবে — কিছু পাঠানো হয়নি।'), links: _pageLink('backup'));
          return;
        }
        _say(out, tr('Drive-এ ব্যাকআপ নিচ্ছি…'), speak: false);
        final err = await brain.backupToDrive();
        _say(out, err == null ? tr('ব্যাকআপ হয়ে গেছে — Google Drive-এ রাখা হলো।') : trf('ব্যাকআপ হয়নি: {0}। এখনকার তথ্য যেমন ছিল আছে।', [err]), links: _pageLink('backup'));

      // ── Settings ──
      case ('settings', 'call_me'):
        final name = c.text.trim();
        await brain.setUserName(name);
        _actions++;
        _say(out, trf('ঠিক আছে, এখন থেকে “{0}” বলে ডাকব। (আগের সব তথ্য যেমন ছিল আছে।)', [name]));
        _offerUndo(snap);
      case ('settings', 'look'):
        await brain.setLook(c.text == 'dark' ? Look.dark : Look.light);
        _say(out, c.text == 'dark' ? tr('ডার্ক মোড চালু করেছি।') : tr('লাইট মোড চালু করেছি।'));
      case ('settings', 'letters'):
        final v = (brain.letterSize + (c.text == 'bigger' ? 0.1 : -0.1)).clamp(0.85, 1.5).toDouble();
        await brain.setLetterSize(v);
        _say(out, c.text == 'bigger' ? tr('লেখা একটু বড় করেছি।') : tr('লেখা একটু ছোট করেছি।'));
      case ('settings', 'ai'):
        _unsupported('settings', tr('AI চালু-বন্ধ সেটিংস থেকে করতে হয়'), out);

      // ── Projects ──
      case ('project', 'create'):
        final exist = projectByName(d, c.target);
        if (exist != null) {
          _say(out, trf('“{0}” হিসাব আগেই আছে — খুলে দিচ্ছি।', [exist.name]), links: _pageLink('projects'));
          return;
        }
        if (!brain.canAddProject) {
          _say(out, tr('ফ্রিতে একটা অন্যান্য হিসাব রাখা যায়; নতুনটা খোলা হয়নি। প্রো নিলে যত খুশি রাখা যাবে।'), links: _pageLink('pro'));
          return;
        }
        await brain.saveProject(Project(name: c.target.trim(), createdAt: _now));
        _actions++;
        _say(out, trf('“{0}” নামে নতুন হিসাব খুলেছি।', [c.target.trim()]), links: _pageLink('projects'));
        _offerUndo(snap);
      case ('project', 'budget' || 'close'):
        final open = d.projects.where((p) => !p.closed).toList();
        final p = c.target.isNotEmpty ? projectByName(d, c.target) : (open.length == 1 ? open.single : null);
        if (p == null) {
          _say(out, open.isEmpty ? tr('কোনো খোলা হিসাব নেই।') : trf('কোন হিসাবটা? — {0}', [nameList([for (final x in open) x.name], unit: 'টা')]), links: _pageLink('projects'));
          return;
        }
        if (c.op == 'budget') {
          await brain.saveProject(Project(id: p.id, name: p.name, createdAt: p.createdAt, closed: p.closed, budget: c.amount));
          _actions++;
          _say(out, trf('“{0}”-এর বাজেট {1} টাকা রাখলাম। এটা পাওয়া টাকা হিসেবে লেখা হয়নি।', [p.name, bnNumber(c.amount)]), links: _pageLink('projects'));
        } else {
          await brain.saveProject(Project(id: p.id, name: p.name, createdAt: p.createdAt, closed: true, budget: p.budget));
          _actions++;
          _say(out, trf('“{0}” শেষ হিসেবে রেখেছি — মুছিনি; পুরোনো হিসাব যেমন ছিল আছে।', [p.name]), links: _pageLink('projects'));
        }
        _offerUndo(snap);

      // ── The shop ──
      case ('shop', 'sale'):
        final shop = _shop(c.target);
        if (d.shops.length > 1 && shop == null) {
          _say(out, trf('কোন দোকানে? — {0}', [nameList([for (final s in d.shops) s.name], unit: 'টা')]), links: _pageLink('shop'));
          return;
        }
        await brain.saveCash(CashEntry(kind: CashKind.income, amount: c.amount, category: salesCategory, note: tr('কথায় বলা'), date: _now, shopId: shop?.id));
        _actions++;
        _say(out, trf('{0}বিক্রি {1} টাকা লিখেছি।', [shop == null ? '' : '${shop.name}: ', bnNumber(c.amount)]), links: _pageLink('shop'));
        _offerUndo(snap);
      case ('shop', 'credit_sale'):
        final shop = _shop('') ;
        final due = c.amount - c.amount2;
        if (c.amount2 > 0) await brain.saveCash(CashEntry(kind: CashKind.income, amount: c.amount2, category: salesCategory, note: c.target, date: _now, shopId: shop?.id));
        if (due > 0) await brain.saveEntry(LedgerEntry(person: c.target, kind: LedgerKind.lent, amount: due, date: dayOnly(_now), note: tr('বাকিতে বিক্রি'), shopId: shop?.id));
        _actions++;
        _say(out, trf('বিক্রি {0} টাকা। পেয়েছেন {1}, বাকি {2} — {3}-এর খাতায় লিখেছি।', [bnNumber(c.amount), bnNumber(c.amount2), bnNumber(due), c.target]),
            links: [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(c.target)]), person: c.target)]);
        _offerUndo(snap);
      case ('shop', 'today'):
        final shop = _shop(c.target);
        final today = dayOnly(_now);
        final rows = d.cash.where((e) => dayOnly(e.date) == today && (shop == null ? e.shopId != null : e.shopId == shop.id)).toList();
        final sales = rows.where((e) => e.kind == CashKind.income).fold(0, (a, e) => a + e.amount);
        final spent = rows.where((e) => e.kind == CashKind.expense).fold(0, (a, e) => a + e.amount);
        _say(out, rows.isEmpty ? trf('{0}আজ দোকানের কোনো হিসাব লেখা নেই।', [shop == null ? '' : '${shop.name}: ']) : trf('{0}আজ বিক্রি (হাতে পাওয়া) {1} টাকা, খরচ {2} টাকা।', [shop == null ? '' : '${shop.name}: ', bnNumber(sales), bnNumber(spent)]),
            links: _pageLink('shop'));
      case ('shop', 'calc'):
        _say(out, trf('{0}টা {1} × {2} টাকা = {3} টাকা। বিক্রি হিসেবে লিখতে চাইলে বলুন “দোকানে {3} টাকা বিক্রি হয়েছে”।', [bnDigits(c.amount), c.text, bnNumber(c.amount2), bnNumber(c.amount * c.amount2)]));
      case ('shop', 'profit'):
        _say(out, tr('কেনা দাম (খরচ) জানা না থাকলে লাভ বলা যায় না। দোকানের খরচগুলো লিখে রাখলে বিক্রি থেকে খরচ বাদে কত থাকল বলতে পারব।'), links: _pageLink('shop'));

      // ── Own money ──
      case ('cash', 'recategorize'):
        final word = fold(c.target);
        final hit = [for (final e in d.cash) if (e.kind == CashKind.expense && (fold(e.note).contains(word) || fold(e.category).contains(word))) e];
        if (hit.isEmpty) {
          _say(out, trf('“{0}”-এর কোনো খরচ খুঁজে পাইনি, কিছু বদলাইনি।', [c.target]), links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))]);
          return;
        }
        hit.sort((a, b) => b.date.compareTo(a.date));
        final e = hit.first;
        final cat = c.text.trim();
        await brain.saveCash(CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: cat, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId, shopId: e.shopId));
        _actions++;
        _say(out, trf('{0} টাকার “{1}” খরচটা ({2}) {3} খাতে সরিয়েছি — টাকা বা তারিখ বদলায়নি।', [bnNumber(e.amount), e.note.isEmpty ? e.category : e.note, shortDate(e.date), cat]),
            links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))]);
        _offerUndo(snap);
      case ('cash', 'dupes'):
        final seen = <String, CashEntry>{};
        (CashEntry, CashEntry)? pair;
        for (final e in [...d.cash]..sort((a, b) => b.date.compareTo(a.date))) {
          final k = '${e.kind.name}|${e.amount}|${e.category}|${dayKey(e.date)}';
          if (seen.containsKey(k)) {
            pair = (seen[k]!, e);
            break;
          }
          seen[k] = e;
        }
        if (pair == null) {
          _say(out, tr('একই দিনে একই খাতে একই টাকার দুটো খরচ পাইনি — কিছু মুছিনি। কোনটা দুবার হয়েছে, খাত আর টাকা বলে আবার বলুন।'), links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))]);
          return;
        }
        final e = pair.$2;
        _clarifyOptions = [
          (tr('হ্যাঁ, একটা মুছো'), MenuAction(c.transcript, domain: 'cash', op: 'delete_one', target: e.id)),
          (tr('না'), SmallTalk(c.transcript, kind: Talk.cancelled)),
        ];
        _ask(out, trf('এই দুটো একই রকম: {0}, {1} টাকা ({2})। একটা মুছে দিই? (৩০ দিন “মুছে ফেলা” থেকে ফেরত আনা যাবে)', [e.category, bnNumber(e.amount), shortDate(e.date)]), ChatWait.clarify,
            choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
      case ('cash', 'delete_one'):
        if (!d.cash.any((x) => x.id == c.target)) return;
        await brain.deleteCash(c.target);
        _actions++;
        _say(out, tr('একটা মুছে দিয়েছি; অন্যটা আছে।'), links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))]);
        _offerUndo(snap);
      case ('cash', _):
        _cashSpan(c, out);
      case ('zakat', 'price'):
        // Today's price from a trusted source (BAJUS, through our server) —
        // never made up; offline, said plainly where to see it.
        final p = await brain.metalPriceToday();
        final z = brain.zakatSaved;
        if (p == null) {
          final price = c.text == 'gold' ? z.goldPrice : z.silverPrice;
          final what = c.text == 'gold' ? tr('সোনা') : tr('রুপা');
          final kept = price <= 0 ? '' : trf(' যাকাত পাতায় {0}র দাম ধরা আছে ভরিপ্রতি {1} টাকা (আপনার লেখা)।', [what, bnNumber(price)]);
          _say(out, tr('এখন আজকের দাম আনতে পারলাম না (ইন্টারনেট বা সার্ভার সাড়া দেয়নি)। বাজুসের সাইটে (bajus.org) আজকের দাম দেখা যায়; আমি নিজে দাম বানিয়ে বলব না।') + kept,
              links: _pageLink('zakat'));
          return;
        }
        final head = trf('আজকের দাম — {0}, {1} থেকে কার্যকর। ', [p.source.isEmpty ? tr('বাজুস') : p.source, shortDate(p.date)]) + p.said();
        if (z.goldPrice == p.gold22 && z.silverPrice == p.silver22) {
          _say(out, '$head ${tr('যাকাত পাতায় এই দামই ধরা আছে।')}', links: _pageLink('zakat'));
          return;
        }
        _clarifyOptions = [
          (tr('হ্যাঁ, বসাও'), MenuAction(c.transcript, domain: 'zakat', op: 'set_price', amount: p.gold22, amount2: p.silver22)),
          (tr('না'), SmallTalk(c.transcript, kind: Talk.cancelled)),
        ];
        _ask(out, '$head ${tr('যাকাতের হিসাবে ২২ ক্যারেটের দাম বসিয়ে দিই?')}', ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
      case ('zakat', 'set_price'):
        final p = await brain.metalPriceToday();
        if (p == null) return;
        await brain.useMetalPrice(p);
        _actions++;
        _say(out, trf('বসিয়ে দিলাম — সোনা ভরি {0}, রুপা ভরি {1} টাকা। এখন “আমার যাকাত কত” জিজ্ঞেস করলে এই দামে হিসাব করব।', [bnNumber(p.gold22), bnNumber(p.silver22)]), links: _pageLink('zakat'));
        _offerUndo(snap);

      // ── Health ──
      case ('health', 'none'):
        _say(out, tr('ঠিক আছে, কোনো মাপ লিখিনি।'));
      case ('health', 'unknown_member'):
        _say(out, trf('“{0}” নামে পরিবারের কোনো সদস্য রাখা নেই, তাই মাপটা কারো নামে লিখিনি। স্বাস্থ্য পাতায় সদস্য যোগ করে আবার বলুন।', [c.target]), links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);
      case ('health', 'height'):
        final cm = c.amount / 10;
        final whose = await brain.setHeight(c.target, cm);
        _actions++;
        _say(out, trf('{0} উচ্চতা {1} সেমি লিখেছি।', [whose, bnDigits(cm.toStringAsFixed(1))]), links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);
        _offerUndo(snap);
      case ('health', 'fix_last'):
        final wrong = c.amount / 10, right = c.amount2 / 10;
        final log = [for (final h in d.health) if (h.member == (c.target.isEmpty ? 'me' : c.target) && (h.a == wrong || h.b == wrong)) h].lastOrNull;
        if (log == null) {
          _say(out, trf('{0} — এমন কোনো মাপ খুঁজে পাইনি, কিছু বদলাইনি।', [bnDigits(wrong.toString())]), links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);
          return;
        }
        final fixed = HealthLog(id: log.id, member: log.member, kind: log.kind, at: log.at, a: log.a == wrong ? right : log.a, b: log.b == wrong ? right : log.b, c: log.c, tag: log.tag, note: log.note);
        await brain.saveHealth(fixed);
        _actions++;
        _say(out, trf('{0}-এর মাপটা ঠিক করেছি: {1}।', [sayWhen(log.at, _now), readingText(fixed)]), links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))]);
        _offerUndo(snap);

      // ── Others ──
      case ('special', 'age'):
        final s = d.specialDays.where((x) => x.person == c.target).firstOrNull;
        if (s == null) return;
        if (s.year == null) {
          _say(out, trf('{0}-এর জন্মদিন {1} {2} রাখা আছে, কিন্তু জন্মসাল নেই — তাই বয়স বলতে পারছি না।', [s.person, bnDigits(s.day), monthName(s.month)]), links: [ChatLink(LinkKind.special, tr('বিশেষ দিন'))]);
        } else {
          final next = s.next(_now);
          _say(out, trf('{0} {1}-এ {2} বছরে পা দেবেন।', [s.person, sayWhen(next, _now, withTime: false), bnDigits(next.year - s.year!)]), links: [ChatLink(LinkKind.special, tr('বিশেষ দিন'))]);
        }
      case ('special', 'month'):
        final m = c.day ?? DateTime(_now.year, _now.month + 1);
        final those = [for (final s in d.specialDays) if (s.month == m.month) s];
        _say(out, those.isEmpty ? trf('{0} মাসে কারো জন্মদিন বা বিশেষ দিন রাখা নেই।', [monthName(m.month)]) : trf('{0} মাসে: {1}।', [monthName(m.month), nameList([for (final s in those) '${specialTitle(s)} (${bnDigits(s.day)})'], unit: 'টা')]),
            links: [ChatLink(LinkKind.special, tr('বিশেষ দিন'))]);
      case ('emergency', 'allergy_none'):
        _say(out, tr('“অ্যালার্জি নেই” — জরুরি কার্ডে এটা অ্যালার্জি হিসেবে লিখিনি, যাতে ভুল না বোঝায়। কার্ডে নিজে “জানা অ্যালার্জি নেই” লিখে রাখতে পারেন।'), links: _pageLink('emergency'));
      case ('vault', 'secret'):
        // Never repeated, never a plain note.
        _say(out, tr('এটা গোপন তথ্য (পিন/পাসওয়ার্ড) — সাধারণ নোটে রাখি না, জোরেও বলি না। পাসওয়ার্ড ভল্টে নিজে টাইপ করে রাখুন; ভল্ট আঙুলের ছাপ বা PIN ছাড়া খোলে না।'), links: _pageLink('vault'));
      case ('app', 'summary'):
        final parts = [
          if (d.tasks.any((t) => !t.done)) trf('বাকি কাজ {0}টা', [bnDigits(d.tasks.where((t) => !t.done).length)]),
          if (d.reminders.any((r) => r.enabled)) trf('চালু রিমাইন্ডার {0}টা', [bnDigits(d.reminders.where((r) => r.enabled).length)]),
          if (d.notes.isNotEmpty) trf('নোট {0}টা', [bnDigits(d.notes.length)]),
          if (d.docs.isNotEmpty) trf('কাগজ {0}টা', [bnDigits(d.docs.length)]),
          if (d.contacts.isNotEmpty) trf('নম্বর {0}টা', [bnDigits(d.contacts.length)]),
          if (d.ledger.isNotEmpty) trf('লেনদেন {0}টা', [bnDigits(d.ledger.length)]),
          if (d.cash.isNotEmpty) trf('আয়-খরচ {0}টা', [bnDigits(d.cash.length)]),
          if (d.medicines.isNotEmpty) trf('ওষুধ {0}টা', [bnDigits(d.medicines.length)]),
          if (d.habits.isNotEmpty) trf('অভ্যাস {0}টা', [bnDigits(d.habits.length)]),
          if (d.specialDays.isNotEmpty) trf('বিশেষ দিন {0}টা', [bnDigits(d.specialDays.length)]),
          if (d.vault.isNotEmpty) trf('ভল্টে {0}টা লগইন (দেখতে আঙুলের ছাপ লাগবে)', [bnDigits(d.vault.length)]),
        ];
        _say(out, parts.isEmpty ? tr('এখনো কিছু রাখা নেই।') : trf('রাখা আছে: {0}।', [parts.join(', ')]), links: _pageLink('store'));
      case ('app', 'why'):
        final heard = [for (final m in messages.reversed.skip(1)) if (m.fromUser) m.text].firstOrNull;
        _say(
            out,
            heard == null
                ? tr('কোন কথাটা? আবার বলুন — লেখা দেখে মিলিয়ে নিন ঠিক শুনেছি কি না।')
                : trf('আমি শুনেছিলাম: “{0}”। এর মধ্যে নিশ্চিত কোনো কাজ ধরতে পারিনি — হয় কোনো শব্দ ভুল শোনা গেছে, নয়তো এ ধরনের কাজ কথায় করা যায় না। লেখাটা ঠিক থাকলে অন্যভাবে বলুন, ভুল হলে আবার বলুন।', [heard]));
      case ('app', 'pro'):
        final p = placeById('pro');
        _say(out, trf('প্রোতে: {0} দাম ও মেয়াদ প্রো পাতায় দেখুন — কেনা না করলে কিছু কাটা হয় না।', [tr(p?.what ?? '')]), links: _pageLink('pro'));
      case ('app', 'why_reminder'):
        final health = await brain.services.notifier.health();
        final exact = await brain.services.notifier.exactAllowed();
        final problems = [
          if (!health.notificationsOn) tr('এই ফোনে অ্যাপের নোটিফিকেশন বন্ধ'),
          if (!exact) tr('“ঠিক সময়ে রিমাইন্ডার” অনুমতি নেই'),
          if (!health.batteryFree) tr('ব্যাটারি সেভার অ্যাপকে থামিয়ে দিতে পারে'),
        ];
        _say(out, problems.isEmpty ? tr('ফোনের দিক থেকে কোনো বাধা দেখছি না। কোন রিমাইন্ডারটা বাজেনি, রিমাইন্ডার পাতায় দেখে নিন — সময়টা ঠিক ছিল কি না।') : trf('সম্ভাব্য কারণ: {0}। সেটিংস থেকে ঠিক করে নিন — খুলে দেওয়া মানে অনুমতি পাওয়া নয়, ফিরে এসে আবার দেখে নেব।', [problems.join('; ')]),
            links: _pageLink('notifications'));
      case ('docs', 'read_unsupported'):
        _say(out, tr('ফাইলের ভেতরের লেখা পড়ার ব্যবস্থা এই অ্যাপে নেই — নাম দেখে আন্দাজে কিছু বলব না। ফাইলটা ডকুমেন্টস থেকে খুলে দেখুন।'), links: _pageLink('docs'));
      case ('diary', _):
        _say(out, tr('ডায়েরি পাতায় দিনের কাজ আর রিমাইন্ডার দেখা যায়; আলাদা লেখা রাখার ব্যবস্থা এখনো নেই, তাই কিছু রাখিনি। চাইলে বলুন “মনে রাখো: …” — নোটে রেখে দেব।'), links: _pageLink('diary'));
      case (_, 'unsupported'):
        _unsupported(c.domain, tr('এই পাতার এ কাজটা'), out);
      default:
        _unsupported(c.domain, tr('এই কাজটা'), out);
    }
  }

  String? _trashKind(String word) {
    final w = fold(word);
    for (final (k, ws) in const [
      ('notes', ['নোট']),
      ('tasks', ['কাজ']),
      ('reminders', ['রিমাইন্ডার', 'অ্যালার্ম']),
      ('ledger', ['লেনদেন']),
      ('cash', ['খরচ', 'আয়']),
      ('contacts', ['নম্বর', 'কন্টাক্ট']),
      ('docs', ['কাগজ', 'ছবি', 'ফাইল']),
      ('memories', ['কথা']),
    ]) {
      if (ws.any((x) => w.startsWith(fold(x)))) return k;
    }
    return null;
  }

  Shop? _shop(String name) {
    final shops = brain.data.shops;
    if (shops.isEmpty) return null;
    if (name.trim().isNotEmpty) {
      final i = _pickNamed(name, [for (final s in shops) s.name]);
      if (i != null) return shops[i];
    }
    return shops.length == 1 ? shops.single : null;
  }

  Future<void> _medicine(MenuAction c, List<String> out, String snap) async {
    final meds = brain.data.medicines;
    if (meds.isEmpty) {
      _say(out, tr('ওষুধের তালিকায় কিছু নেই, তাই কিছু লিখিনি। ওষুধ পাতায় নাম আর সময় দিয়ে যোগ করুন।'), links: _pageLink('medicines'));
      return;
    }
    final i = _pickNamed(c.target, [for (final m in meds) m.name]);
    Medicine? m = i == null ? null : meds[i];
    final link = _pageLink('medicines');
    switch (c.op) {
      case 'stock_query':
        final list = m == null ? meds : [m];
        final lines = [for (final x in list) x.daysLeft == null ? trf('{0}: কতগুলো আছে লেখা নেই', [x.name]) : trf('{0}: {1}টা আছে — আরও {2} দিন চলবে', [x.name, bnDigits(x.stock), bnDigits(x.daysLeft!)])];
        _say(out, list.length == 1 ? '${lines.single}।' : tr('ওষুধের হিসাব:'), facts: list.length == 1 ? const [] : lines, links: link);
        return;
      case 'stock_add':
        if (m == null) break;
        final added = c.amount;
        await brain.saveMedicine(m.copyWith(stock: m.stock + added));
        _actions++;
        _say(out, trf('{0} — {1}টা যোগ করেছি, এখন {2}টা আছে। খাওয়ার হিসাবে কিছু লিখিনি।', [m.name, bnDigits(added), bnDigits(m.stock + added)]), links: link);
        _offerUndo(snap);
        return;
      case 'reminder_off':
        if (m == null) break;
        var n = 0;
        for (final id in m.reminderIds) {
          final r = brain.data.reminders.where((x) => x.id == id && x.enabled).firstOrNull;
          if (r == null) continue;
          await brain.saveReminder(r.copyWith(enabled: false));
          n++;
        }
        _actions++;
        _say(out, n == 0 ? trf('{0}-এর কোনো চালু রিমাইন্ডার ছিল না। ওষুধটা তালিকায় আছে।', [m.name]) : trf('{0}-এর রিমাইন্ডার বন্ধ করেছি; ওষুধটা তালিকায় আছে।', [m.name]), links: link);
        _offerUndo(snap);
        return;
    }
    // A dose: which medicine and which time of today.
    final day = c.day ?? dayOnly(_now);
    final candidates = m != null ? [m] : meds;
    int? slotOf(Medicine x) {
      if (c.part.isNotEmpty) {
        final range = switch (c.part) { 'সকাল' => (4 * 60, 12 * 60), 'দুপুর' => (12 * 60, 15 * 60), 'বিকেল' => (15 * 60, 18 * 60), 'সন্ধ্যা' => (17 * 60, 20 * 60), _ => (19 * 60, 28 * 60) };
        return x.times.where((t) => t >= range.$1 && t < range.$2).firstOrNull;
      }
      // No part said: the latest time already come today (or the only one).
      final mins = _now.hour * 60 + _now.minute;
      final past = x.times.where((t) => dayOnly(day) != dayOnly(_now) || t <= mins + 60).toList()..sort();
      if (c.op == 'dose') return past.where((t) => !x.takenAt(day, t)).lastOrNull ?? (x.times.length == 1 ? x.times.single : null);
      if (c.op == 'dose_not') return past.lastOrNull ?? x.times.firstOrNull;
      return past.where((t) => x.takenAt(day, t)).lastOrNull;
    }

    final hits = [for (final x in candidates) if (slotOf(x) != null) (x, slotOf(x)!)];
    if (hits.isEmpty) {
      _say(out, trf('{0} কোন ডোজ — ধরতে পারিনি, তাই কিছু লিখিনি। ওষুধের নাম আর সময় বলুন — যেমন “নাপা সকালেরটা খেয়েছি”।', [c.part.isEmpty ? '' : '${c.part}ের']), links: link);
      return;
    }
    if (hits.length > 1 && m == null) {
      _say(out, trf('কোন ওষুধ? — {0}। নামসহ আরেকবার বলুন।', [nameList([for (final h in hits) h.$1.name], unit: 'টা')]), links: link);
      return;
    }
    final (med, slot) = hits.first;
    final at = bnTime(slot ~/ 60, slot % 60);
    switch (c.op) {
      case 'dose':
        if (med.takenAt(day, slot)) {
          _say(out, trf('{0} ({1}) খাওয়ার টিক আগেই দেওয়া আছে — আবার দিইনি।', [med.name, at]), links: link);
          return;
        }
        await brain.toggleDose(med, day, slot);
        _actions++;
        _say(out, trf('{0} — {1}-এর ডোজ খাওয়ার টিক দিয়েছি।', [med.name, at]), links: link);
        _offerUndo(snap);
      case 'dose_not':
        _say(out, med.takenAt(day, slot) ? trf('{0} ({1}) খাওয়া হিসেবে টিক দেওয়া আছে। ভুল হলে বলুন “ভুল করে টিক দিয়েছি”।', [med.name, at]) : trf('ঠিক আছে, {0} ({1}) এখনো খাওয়া হয়নি হিসেবেই আছে।', [med.name, at]), links: link);
      case 'dose_undo':
        if (!med.takenAt(day, slot)) {
          _say(out, trf('{0} ({1}) খাওয়ার টিক দেওয়া ছিল না।', [med.name, at]), links: link);
          return;
        }
        await brain.toggleDose(med, day, slot);
        _actions++;
        _say(out, trf('{0} ({1}) — টিক তুলে দিয়েছি{2}।', [med.name, at, med.stock > 0 ? tr(', গোনা ওষুধও ফেরত যোগ হলো') : '']), links: link);
        _offerUndo(snap);
    }
  }

  void _cashSpan(MenuAction c, List<String> out) {
    final d = brain.data;
    final from = c.day!, to = c.until!;
    final rows = [for (final e in d.cash) if (!e.date.isBefore(from) && e.date.isBefore(to) && e.projectId == null && (c.text.isEmpty || e.category == c.text)) e];
    final spent = rows.where((e) => e.kind == CashKind.expense).fold(0, (a, e) => a + e.amount);
    final got = rows.where((e) => e.kind == CashKind.income).fold(0, (a, e) => a + e.amount);
    final cat = c.text.isEmpty ? '' : trf('{0} খাতে ', [c.text]);
    final link = [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))];
    switch (c.op) {
      case 'income':
        _say(out, got == 0 ? trf('{0} {1}কোনো আয় লেখা নেই।', [c.target, cat]) : trf('{0} {1}আয় {2} টাকা।', [c.target, cat, bnNumber(got)]), links: link);
      case 'net':
        final net = got - spent;
        _say(out, trf('{0} আয় {1}, খরচ {2} — {3}।', [c.target, bnNumber(got), bnNumber(spent), net >= 0 ? trf('হাতে থাকে {0} টাকা (ব্যালেন্স)', [bnNumber(net)]) : trf('আয়ের চেয়ে {0} টাকা বেশি খরচ', [bnNumber(-net)])]), links: link);
      default:
        final items = rows.where((e) => e.kind == CashKind.expense).toList()..sort((a, b) => b.amount.compareTo(a.amount));
        _say(out, spent == 0 ? trf('{0} {1}কোনো খরচ লেখা নেই।', [c.target, cat]) : trf('{0} {1}খরচ {2} টাকা ({3}টা)।', [c.target, cat, bnNumber(spent), bnDigits(items.length)]),
            facts: [for (final e in items.take(10)) '${e.category}${e.note.isEmpty ? '' : ' — ${e.note}'}: ${bnNumber(e.amount)} ${tr('টাকা')} (${shortDate(e.date)})'], links: link);
    }
  }
}
