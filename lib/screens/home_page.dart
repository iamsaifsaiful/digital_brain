import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/cash.dart';
import '../logic/lang.dart';
import '../logic/ledger.dart' show totals;
import '../logic/add_nudges.dart';
import '../logic/money_quotes.dart';
import '../logic/phrases.dart' show possessive;
import '../logic/sky_light.dart';
import '../logic/spend_health.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/pro_gate.dart';
import '../ui/theme.dart';
import 'alarm_list_screen.dart';
import 'app_places.dart' show openPlace;
import 'calendar_screen.dart';
import 'calls_screen.dart';
import 'compass_screen.dart';
import 'docs_screen.dart';
import 'easy_home.dart';
import 'family_screen.dart';
import 'health_hub.dart';
import 'home_screen.dart';
import 'home_shell.dart';
import 'notes_screen.dart';
import 'notice_screen.dart';
import 'plan_screens.dart';
import 'pro_screen.dart';
import 'requests_screen.dart';
import 'settings_parts.dart';
import 'spend_health_screen.dart';
import 'vault_screen.dart';
import 'zakat_screen.dart';

String helloFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return tr('সুপ্রভাত');
  if (h >= 11 && h < 15) return tr('শুভ দুপুর');
  if (h >= 15 && h < 18) return tr('শুভ বিকেল');
  if (h >= 18 && h < 22) return tr('শুভ সন্ধ্যা');
  return tr('শুভ রাত');
}

/// হোম (the approved design of 24 Oct, docs/design/2026-10-24-home-final):
/// the greeting and today's three dates, weather and the next prayer, at
/// most one thing that needs a look, today's work, the money with a line
/// about money under it, the coming holidays, every tool, and the privacy note.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (brain.easyMode) return const EasyHome();
    final now = brain.services.now();
    final quote = quoteFor(now);

    // The picture runs under the phone's status bar: its icons go white there.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: C.ground,
        systemNavigationBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
      ),
      child: ColoredBox(
      color: C.ground,
      child: Stack(children: [
      ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const HomeHero(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const HomeAttention(),
          const TodaySections(),
          const _MoneyCard(),
          // আজকের অর্থ-কথা right under the money (owner, 24 Oct night).
          const SizedBox(height: 12),
          AppCard(
            key: const Key('home-quote'),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.format_quote_rounded, size: 20, color: C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(quote.text), style: body(13.5, height: 1.6)),
                  const SizedBox(height: 2),
                  Text(quote.source.isEmpty ? tr('আজকের অর্থ-কথা') : '${tr('আজকের অর্থ-কথা')} · ${tr(quote.source)}', style: body(11.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
          const _Holidays(),
          const SizedBox(height: 14),
          const _Tools(),
          const SizedBox(height: 12),
          // Free Play app only: a quiet ad card under the quote.
          const AdSlot(padding: EdgeInsets.only(top: 12)),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: C.muted),
              const SizedBox(width: 5),
              Flexible(child: Text(tr('আপনার তথ্য এই ফোনেই থাকে, তালাবদ্ধ'), style: body(11.5, color: C.muted))),
            ]),
          ),
            ]),
          ),
        ],
      ),
      // কিছু যুক্ত করুন: one empty menu at a time, floating over the bottom.
      const Positioned(left: 16, right: 16, bottom: 12, child: AddNudgeCard()),
      ]),
      ),
    );
  }
}

/// The floating "… যুক্ত করুন" message (owner, 25 Oct): turns between the
/// empty menus every few seconds; a tap opens that menu; ✕ hides them all
/// for a day. Menus with something in them never show.
class AddNudgeCard extends StatefulWidget {
  const AddNudgeCard({super.key});

  @override
  State<AddNudgeCard> createState() => _AddNudgeCardState();
}

class _AddNudgeCardState extends State<AddNudgeCard> {
  int _i = 0;
  Timer? _turn;

  @override
  void initState() {
    super.initState();
    _turn = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _turn?.cancel();
    super.dispose();
  }

  static IconData _icon(String id) => switch (id) {
        'tasks' => Icons.checklist_rounded,
        'reminders' => Icons.notifications_none_rounded,
        'money' => Icons.account_balance_wallet_outlined,
        'ledger' => Icons.handshake_outlined,
        'notes' => Icons.description_outlined,
        'docs' => Icons.folder_outlined,
        'vault' => Icons.lock_outline_rounded,
        'contacts' => Icons.person_outline_rounded,
        'health' => Icons.monitor_heart_outlined,
        'medicines' => Icons.medication_outlined,
        'habits' => Icons.repeat_rounded,
        'special' => Icons.cake_outlined,
        'savings' => Icons.savings_outlined,
        'backup' => Icons.cloud_upload_outlined,
        _ => Icons.alarm_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (!brain.loaded || brain.easyMode) return const SizedBox.shrink();
    if (!nudgesShown(brain.services.now(), DateTime.tryParse(brain.text('nudges_hidden_at')))) return const SizedBox.shrink();
    final list = addNudges(brain.data, lastBackup: DateTime.tryParse(brain.text('last_backup')), now: brain.services.now());
    if (list.isEmpty) return const SizedBox.shrink();
    final n = list[_i % list.length];
    return Material(
      key: const Key('add-nudge'),
      color: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: C.green.withValues(alpha: 0.45))),
      child: InkWell(
        key: Key('add-nudge-${n.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => openPlace(context, n.place),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(children: [
            IconTile(_icon(n.id), size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(tr(n.text), key: ValueKey(n.id), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
            IconButton(
              key: const Key('add-nudge-close'),
              tooltip: tr('এখন না'),
              visualDensity: VisualDensity.compact,
              onPressed: () => brain.setPref('nudges_hidden_at', brain.services.now().toIso8601String()),
              icon: Icon(Icons.close_rounded, size: 18, color: C.muted),
            ),
          ]),
        ),
      ),
    );
  }
}

/// What the right side of the info row turns between: the next prayer, then
/// sunrise and sunset; in Ramadan, iftar (Fajr to Maghrib) or the end of
/// sehri (Maghrib to Fajr) instead of the prayer. Times are worked out on
/// the phone for the district.
class SlotFact {
  const SlotFact(this.kind, this.label, this.time, {this.second = '', this.ramadanDay});

  /// 'prayer', 'iftar', 'sehri' or 'sun'.
  final String kind;
  final String label;
  final String time;

  /// The sun slide's second line ("সূর্যাস্ত ৫:২৪").
  final String second;

  /// In Ramadan: its day ("রমজান ১৪").
  final int? ramadanDay;
}

List<SlotFact> slotFacts(DateTime now, SunTimes t, HijriDate hj) {
  String at(DateTime x) => bnTime(x.hour, x.minute).replaceAll(RegExp(r'^(?:ভোর|সকাল|দুপুর|বিকেল|সন্ধ্যা|রাত)\s*'), '');
  final out = <SlotFact>[];
  if (hj.month == 9) {
    final beforeIftar = !now.isBefore(t.sehriEnd) && now.isBefore(t.maghrib);
    out.add(beforeIftar
        ? SlotFact('iftar', tr('ইফতার'), at(t.maghrib), ramadanDay: hj.day)
        : SlotFact('sehri', tr('সেহরি শেষ'), at(t.sehriEnd), ramadanDay: hj.day));
  } else {
    final prayers = [(tr('ফজর'), t.fajr), (now.weekday == DateTime.friday ? tr('জুমা') : tr('জোহর'), t.dhuhr), (tr('আসর'), t.asr), (tr('মাগরিব'), t.maghrib), (tr('এশা'), t.isha)];
    // The next one; after Isha, still Isha until midnight, then tomorrow's Fajr.
    final next = prayers.where((p) => p.$2.isAfter(now)).firstOrNull ?? (now.hour >= 12 ? prayers.last : prayers.first);
    out.add(SlotFact('prayer', next.$1, at(next.$2)));
  }
  out.add(SlotFact('sun', tr('সূর্যোদয়'), at(t.sunrise), second: '${tr('সূর্যাস্ত')} ${at(t.sunset)}'));
  return out;
}

/// The top of the home (owner, 24 Oct night): the owner's painting of a
/// river bank, lit by the time of day ([skyLight]: dawn, morning, noon,
/// afternoon, evening, night), with the greeting and today's three dates,
/// the bell and the photo, the temperature with the sky and the district,
/// the next prayer (in Ramadan iftar or the end of sehri), and sunrise and
/// sunset along the bottom. It fades into the page below.
class HomeHero extends StatefulWidget {
  const HomeHero({super.key});

  @override
  State<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<HomeHero> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BrainScope.read(context).refreshWeather();
    });
    // While the home is open: the light moves on with the clock, the place
    // follows the phone (checked every 10 min at most) and the weather is
    // fetched again when half an hour old.
    _tick = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      setState(() {});
      final brain = BrainScope.read(context);
      brain.refreshPlace();
      brain.refreshWeather();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Both pictures ready before the light needs them (no day flash at night).
    precacheImage(const AssetImage('assets/sky/day.jpg'), context);
    precacheImage(const AssetImage('assets/sky/night.jpg'), context);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static const _white = Colors.white;
  static final _soft = Colors.white.withValues(alpha: 0.86);
  static const _shade = [Shadow(color: Color(0x59000000), blurRadius: 10)];

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final place = placeNamed(brain.district);
    final sun = sunTimes(now, place);
    final hj = hijriDate(now, adjust: brain.hijriShift);
    final light = skyLight(now, sun.sunrise, sun.sunset);
    final facts = slotFacts(now, sun, hj);
    final top = MediaQuery.of(context).padding.top;
    final height = top + 318.0;
    // In the dark look the day is a little dimmer, so it sits with the page.
    final dim = (light.dim + (C.dark ? 0.16 * (1 - light.night) : 0)).clamp(0.0, 0.6);

    Widget picture = Stack(fit: StackFit.expand, children: [
      Image.asset('assets/sky/day.jpg', fit: BoxFit.cover, alignment: const Alignment(0, 0.55), gaplessPlayback: true, excludeFromSemantics: true),
      if (light.night > 0)
        Opacity(
          opacity: light.night.clamp(0.0, 1.0),
          child: Image.asset('assets/sky/night.jpg', fit: BoxFit.cover, alignment: const Alignment(0, 0.55), gaplessPlayback: true, excludeFromSemantics: true),
        ),
    ]);
    if (light.tintAmount > 0.01) {
      // Clipped: a colour filter's layer has no edge of its own and would tint the whole page.
      picture = ClipRect(child: ColorFiltered(colorFilter: ColorFilter.mode(light.tint.withValues(alpha: light.tintAmount), BlendMode.softLight), child: picture));
    }

    return SizedBox(
      key: Key('home-hero-${light.phase}'),
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        picture,
        if (dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
        // A veil at the top for the words, and the fade into the page.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.42, 0.8, 1], colors: [
              Colors.black.withValues(alpha: 0.30),
              Colors.black.withValues(alpha: 0),
              C.ground.withValues(alpha: 0),
              C.ground,
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 8, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _greeting(context, brain, now, hj),
            const SizedBox(height: 10),
            _weather(brain, sun, now),
            const SizedBox(height: 14),
            _prayer(context, facts.first),
            const Spacer(),
            _sunRow(facts.last),
          ]),
        ),
      ]),
    );
  }

  /// "শুভ বিকেল, সাইফুল", today in three calendars, the bell and the photo.
  Widget _greeting(BuildContext context, Brain brain, DateTime now, HijriDate hj) {
    final bd = banglaDate(now);
    final first = brain.userName.trim().isEmpty ? '' : brain.userName.trim().split(' ').first;
    final seen = DateTime.tryParse(brain.text('notices_seen'));
    final unread = brain.noticeHistory.any((e) => !e.at.isAfter(now) && (seen == null || e.at.isAfter(seen)));
    final premium = brain.gated && brain.pro;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => push(const CalendarScreen()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(first.isEmpty ? helloFor(now) : '${helloFor(now)}, $first',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: display(25, weight: 600, height: 1.3, color: _white).copyWith(shadows: _shade)),
            const SizedBox(height: 2),
            Text('${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}', style: body(13.5, color: _soft).copyWith(shadows: _shade)),
            const SizedBox(height: 2),
            Text('${bd.text}  •  ${hj.dayMonth} ${bnDigits(hj.year)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: _soft).copyWith(shadows: _shade)),
          ]),
        ),
      ),
      SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          key: const Key('home-notices'),
          tooltip: tr('নোটিফিকেশন'),
          onPressed: () async {
            await brain.setPref('notices_seen', now.toIso8601String());
            push(const NoticeScreen());
          },
          icon: Stack(clipBehavior: Clip.none, children: [
            const Icon(Icons.notifications_none_rounded, size: 25, color: _white, shadows: _shade),
            if (unread)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  key: const Key('home-unread'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFF5B841), shape: BoxShape.circle),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      Tooltip(
        message: tr('প্রোফাইল'),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => goToTab(context, ShellTab.more),
          child: SizedBox(
            width: 48,
            height: 54,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: UserPhoto(size: 42, onDark: true)),
              if (premium)
                Positioned(
                  bottom: 0,
                  child: Container(
                    key: const Key('home-premium-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(5), border: Border.all(color: _white, width: 1.5)),
                    child: Text(tr('প্রিমিয়াম'), style: body(8.5, weight: FontWeight.w700, color: C.onAccent, height: 1.3)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  /// "৩১°  রোদ · ঢাকা / ↑৩২° ↓২৪° · অনুভূত ৩৪°" (or the district alone before the weather comes).
  Widget _weather(Brain brain, SunTimes sun, DateTime now) {
    final w = brain.weatherNow;
    final day = !now.isBefore(sun.sunrise) && now.isBefore(sun.sunset);
    if (w == null) {
      return Row(children: [
        const Icon(Icons.place_outlined, size: 18, color: _white, shadows: _shade),
        const SizedBox(width: 6),
        Flexible(child: Text(brain.placeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade))),
      ]);
    }
    final sky = day && w.code <= 1 ? tr('রোদ') : w.sky;
    return Tooltip(
      key: const Key('home-temp'),
      message: w.said(),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(w.short, style: display(62, weight: 400, height: 1.05, color: _white).copyWith(shadows: _shade)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$sky · ${brain.placeLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16.5, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade)),
            // Arrows as icons: neither font has ↑ ↓ (they showed as boxes).
            Text.rich(
              TextSpan(children: [
                WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.arrow_upward_rounded, size: 13, color: _soft, shadows: _shade)),
                TextSpan(text: '${bnDigits(w.max.round())}°  '),
                WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.arrow_downward_rounded, size: 13, color: _soft, shadows: _shade)),
                TextSpan(text: '${bnDigits(w.min.round())}° · ${trf('অনুভূত {0}°', [bnDigits(w.feels.round())])}'),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(12.5, color: _soft).copyWith(shadows: _shade),
            ),
          ]),
        ),
      ]),
    );
  }

  /// The next prayer (iftar / end of sehri in Ramadan) in a glass pill.
  Widget _prayer(BuildContext context, SlotFact f) {
    final icon = f.kind == 'prayer' ? Icons.mosque_outlined : Icons.nightlight_outlined;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-slot'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: _white),
            const SizedBox(width: 8),
            if (f.ramadanDay != null) ...[
              Text(trf('রমজান {0}', [bnDigits(f.ramadanDay!)]), style: body(12, weight: FontWeight.w600, color: _soft)),
              Text('  ·  ', style: body(12, color: _soft)),
            ],
            Text('${f.label} ${f.time}', style: body(15, weight: FontWeight.w600, color: _white)),
          ]),
        ),
      ),
    );
  }

  /// Sunrise on the left, sunset on the right, along the river.
  Widget _sunRow(SlotFact f) {
    final style = body(12.5, weight: FontWeight.w500, color: _white).copyWith(shadows: _shade);
    return Row(children: [
      const Icon(Icons.wb_twilight_rounded, size: 17, color: _white, shadows: _shade),
      const SizedBox(width: 5),
      Text('${f.label} ${f.time}', style: style),
      const Spacer(),
      const Icon(Icons.nightlight_outlined, size: 16, color: _white, shadows: _shade),
      const SizedBox(width: 5),
      Text(f.second, style: style),
    ]);
  }
}

/// টাকার হিসাব: what is in hand, this month's in and out, পাবো / দেবো, and the week.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final today = dayOnly(now);
    final month = monthSums(d.cash, now);
    final hand = cashOnHand(d);
    final owe = totals(d.ledger);
    final week = spendHealth(d, now);
    final weekWarn = week.hasIncome && (week.pct(week.wants) > wantCap || week.spent > week.income);
    // A pay-back day today, and the next day I have to give back.
    final dueToday = d.ledger.where((e) => e.kind == LedgerKind.lent && e.due != null && dayOnly(e.due!) == today).map((e) => e.person).toSet();
    final nextGive = (d.ledger.where((e) => e.kind == LedgerKind.borrowed && e.due != null && !dayOnly(e.due!).isBefore(today)).toList()
          ..sort((a, b) => a.due!.compareTo(b.due!)))
        .firstOrNull;
    void money() => goToTab(context, ShellTab.money);

    Widget stat(IconData icon, String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: C.muted), const SizedBox(width: 4), Text(label, style: body(11.5, color: C.muted))]),
          const SizedBox(height: 4),
          Text(value, style: body(14, weight: FontWeight.w600, color: color)),
        ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('টাকার হিসাব'), link: '${monthName(now.month)} · ${tr('খুলুন')}', onLink: money),
      AppCard(
        key: const Key('home-stat-spent'),
        onTap: money,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hand != null ? tr('এখন আছে') : tr('হাতে থাকল'), style: body(11.5, color: C.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(taka(hand ?? month.balance), style: display(27, weight: 600, height: 1.45)),
                ),
              ]),
            ),
            const IconTile(Icons.account_balance_wallet_outlined),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            stat(Icons.south_rounded, tr('আয়'), taka(month.income), C.green),
            const SizedBox(width: 26),
            stat(Icons.north_rounded, tr('খরচ'), taka(month.expense), C.ink),
          ]),
          const SizedBox(height: 12),
          if (owe.receivable > 0 || owe.payable > 0) ...[
            const Hairline(),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('পাবো · {0} জনের কাছে', [bnDigits(owe.owingPeople)]), style: body(11.5, color: C.muted)),
                      Text(taka(owe.receivable), style: body(15, weight: FontWeight.w600)),
                      if (dueToday.isNotEmpty)
                        Text(trf('আজ {0} ফেরতের দিন', [dueToday.map(possessive).join(', ')]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: C.warn)),
                    ]),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: C.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('দেবো · {0} জনকে', [bnDigits(owe.owedPeople)]), style: body(11.5, color: C.muted)),
                      Text(taka(owe.payable), style: body(15, weight: FontWeight.w600, color: owe.payable > 0 ? C.warn : C.ink)),
                      if (nextGive != null) Text('${nextGive.person} · ${bnDigits(nextGive.due!.day)} ${monthName(nextGive.due!.month)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: C.muted)),
                    ]),
                  ),
                ),
              ]),
            ),
          ],
          if (week.spent > 0) ...[
            const Hairline(),
            InkWell(
              key: const Key('home-spend-health'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpendHealthScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 17, color: weekWarn ? C.warn : C.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      week.hasIncome
                          ? trf('এ সপ্তাহে আয়ের {0}% খরচ — শখের খাতে {1}%', [bnDigits(week.pct(week.spent)), bnDigits(week.pct(week.wants))])
                          : trf('এ সপ্তাহে খরচ {0} — কোথায় যাচ্ছে দেখুন', [taka(week.spent)]),
                      style: body(12.5, color: weekWarn ? C.warn : C.ink),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
                ]),
              ),
            ),
          ] else
            const SizedBox(height: 2),
        ]),
      ),
    ]);
  }
}

/// সামনের ছুটি: the holiday going on now or the next two (always on the home).
class _Holidays extends StatelessWidget {
  const _Holidays();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final runs = upcomingHolidays(now, count: 2);
    if (runs.isEmpty) return const SizedBox.shrink();
    void cal() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('সামনের ছুটি'), link: tr('ক্যালেন্ডার'), onLink: cal),
      AppCard(
        key: const Key('home-holidays'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          for (final (i, h) in runs.indexed) ...[
            if (i > 0) const Hairline(),
            InkWell(
              onTap: cal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Builder(builder: (context) {
                  final days = DateTime(h.start.year, h.start.month, h.start.day).difference(today).inDays;
                  return Row(children: [
                    _DateBox(day: h.start.day, month: monthShort(h.start.month)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(days <= 0 ? trf('আজ ছুটি — {0}', [h.label]) : h.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w500)),
                        Text(h.days > 1 ? '${weekdayName(h.start)} · ${holidayRange(h)}, ${trf('টানা {0} দিন', [bnDigits(h.days)])}' : weekdayName(h.start),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Counter(days > 0 ? trf('{0} দিন পর', [bnDigits(days)]) : tr('চলছে')),
                  ]);
                }),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.day, required this.month});
  final int day;
  final String month;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 46,
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(bnDigits(day), style: body(17, weight: FontWeight.w700, height: 1.15)),
          Text(month, maxLines: 1, overflow: TextOverflow.clip, style: body(10.5, color: C.muted, height: 1.2)),
        ]),
      );
}

/// সব সুবিধা: every tool, always open (owner, 24 Oct night).
class _Tools extends StatelessWidget {
  const _Tools();

  @override
  Widget build(BuildContext context) {
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final tools = <(String, IconData, VoidCallback)>[
      (tr('কাজের তালিকা'), Icons.checklist_rounded, () => goToTab(context, ShellTab.diary)),
      (tr('রিমাইন্ডার'), Icons.notifications_none_rounded, () => push(const AllTasksScreen())),
      (tr('ডকুমেন্টস'), Icons.folder_outlined, () => push(const DocsScreen())),
      (tr('নোট'), Icons.description_outlined, () => push(const NotesScreen())),
      (tr('যোগাযোগ'), Icons.person_outline_rounded, () => push(const CallsScreen())),
      (tr('স্বাস্থ্য'), Icons.monitor_heart_outlined, () => push(const HealthScreen())),
      (tr('অ্যালার্ম'), Icons.alarm_rounded, () => push(const AlarmsScreen())),
      (tr('পাসওয়ার্ড'), Icons.lock_outline_rounded, () => push(const VaultPage())),
      (tr('ক্যালেন্ডার'), Icons.calendar_month_outlined, () => push(const CalendarScreen())),
      (tr('কম্পাস'), Icons.explore_outlined, () => push(const CompassScreen())),
      (tr('যাকাত'), Icons.volunteer_activism_outlined, () => push(const ZakatScreen())),
      (tr('ফ্যামিলি'), Icons.family_restroom_rounded, () => push(const FamilyScreen())),
      (tr('ব্লাড ডোনেশন'), Icons.bloodtype_outlined, () => push(const RequestsScreen())),
      (tr('প্রিমিয়াম'), Icons.workspace_premium_outlined, () => push(const ProScreen())),
    ];
    return AppCard(
      key: const Key('home-tools'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: [
        SizedBox(
          height: 50,
          child: Row(children: [
            Text(tr('সব সুবিধা'), style: body(14, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(trf('{0}টা', [bnDigits(tools.length)]), style: body(12, color: C.muted)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 18) / 4;
            return Wrap(spacing: 6, runSpacing: 4, children: [
              for (final (label, icon, onTap) in tools) SizedBox(width: w, child: ToolTile(icon: icon, label: label, onTap: onTap)),
            ]);
          }),
        ),
      ]),
    );
  }
}

/// "২০–২৪ অক্টোবর", or "১৬ ডিসেম্বর".
String holidayRange(HolidayRun r) {
  if (r.days == 1) return '${bnDigits(r.start.day)} ${monthName(r.start.month)}';
  if (r.start.month == r.end.month) return '${bnDigits(r.start.day)}–${bnDigits(r.end.day)} ${monthName(r.start.month)}';
  return '${bnDigits(r.start.day)} ${monthName(r.start.month)} – ${bnDigits(r.end.day)} ${monthName(r.end.month)}';
}
