import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'compass_screen.dart' show QiblaView;

/// The three parts of মুসলিম টাইম.
enum IbadahTab { prayer, fasting, qibla }

/// মুসলিম টাইম (owner, 19 Nov: "হোমে, ক্যালেন্ডারে নামাজের সময় লাগবে না; কম্পাস
/// মেনুর ভেতরে নিয়ে যাও … সেহরি, ইফতারের সময় সূচিও"): the day's prayer
/// times, sehri and iftar with the Ramadan timetable, and the qibla. Times
/// are worked out on the phone for the profile's place.
class IbadahScreen extends StatefulWidget {
  const IbadahScreen({super.key, this.tab = IbadahTab.prayer});
  final IbadahTab tab;

  @override
  State<IbadahScreen> createState() => _IbadahScreenState();
}

class _IbadahScreenState extends State<IbadahScreen> {
  late IbadahTab _tab = widget.tab;

  /// Days from today shown on the prayer tab (‹ ›).
  int _day = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The next prayer's "আর … বাকি" moves on with the clock.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final place = placeNamed(brain.district);
    final hj = hijriDate(now, adjust: brain.hijriShift);
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TopBar(title: tr('মুসলিম টাইম')),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 20, 10),
            child: Row(children: [
              Icon(Icons.place_outlined, size: 16, color: C.muted),
              const SizedBox(width: 4),
              Flexible(child: Text(place.label, key: const Key('ibadah-place'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted))),
              Text('  ·  ', style: body(13, color: C.muted)),
              Flexible(child: Text(hj.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegTabs<IbadahTab>(
              key: const Key('ibadah-tabs'),
              items: [(IbadahTab.prayer, tr('নামাজ')), (IbadahTab.fasting, tr('সেহরি ও ইফতার')), (IbadahTab.qibla, tr('কিবলা'))],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: switch (_tab) {
              IbadahTab.prayer => _prayers(brain, now, place),
              IbadahTab.fasting => _fasting(brain, now, place),
              IbadahTab.qibla => const QiblaView(),
            },
          ),
        ]),
      ),
    );
  }

  // ── নামাজ ──

  Widget _prayers(Brain brain, DateTime now, Place place) {
    final today = DateTime(now.year, now.month, now.day);
    final day = today.add(Duration(days: _day));
    final t = sunTimes(day, place);
    final friday = day.weekday == DateTime.friday;
    final list = <(String, IconData, DateTime, DateTime?)>[
      (tr('ফজর'), Icons.wb_twilight_outlined, t.fajr, t.sunrise),
      (friday ? tr('জুমা') : tr('জোহর'), Icons.wb_sunny_outlined, t.dhuhr, t.asr),
      (tr('আসর'), Icons.filter_drama_outlined, t.asr, t.maghrib),
      (tr('মাগরিব'), Icons.wb_twilight_rounded, t.maghrib, t.isha),
      (tr('এশা'), Icons.nightlight_outlined, t.isha, null),
    ];
    // The waqt now (today only): Fajr until sunrise, the rest until the next; Isha until Fajr.
    var current = -1;
    if (_day == 0) {
      if (now.isBefore(t.fajr) || !now.isBefore(t.isha)) {
        current = 4;
      } else {
        for (var i = 0; i < 4; i++) {
          if (!now.isBefore(list[i].$3) && now.isBefore(list[i].$4!)) current = i;
        }
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 24), children: [
      if (_day == 0) _nextCard(now, place, t),
      if (_day == 0) const SizedBox(height: 12),
      Row(children: [
        IconButton(
          key: const Key('ibadah-day-back'),
          tooltip: tr('আগের দিন'),
          onPressed: _day <= -30 ? null : () => setState(() => _day--),
          icon: Icon(Icons.chevron_left_rounded, color: C.ink),
        ),
        Expanded(
          child: Column(children: [
            Text(_day == 0 ? tr('আজ') : relativeDay(day, today), style: body(14.5, weight: FontWeight.w600)),
            Text('${weekdayName(day)}, ${fullDate(day)}', style: body(12, color: C.muted)),
          ]),
        ),
        IconButton(
          key: const Key('ibadah-day-next'),
          tooltip: tr('পরের দিন'),
          onPressed: _day >= 30 ? null : () => setState(() => _day++),
          icon: Icon(Icons.chevron_right_rounded, color: C.ink),
        ),
      ]),
      const SizedBox(height: 6),
      Panel(
        child: Column(children: [
          for (final (i, p) in list.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: C.line),
            _waqtRow(p.$1, p.$2, p.$3, now: i == current, until: p.$4),
            // Sunrise after Fajr: the end of Fajr, not a prayer.
            if (i == 0) ...[
              Divider(height: 1, indent: 56, color: C.line),
              _sunRow(tr('সূর্যোদয়'), Icons.wb_sunny_outlined, t.sunrise, tr('ফজরের শেষ')),
            ],
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Text(
        trf('{0} অনুযায়ী আনুমানিক সময় · {1}, আসর হানাফি। আজান ও জামাতের সময় নিজের মসজিদের সঙ্গে মিলিয়ে নিন।', [place.label, _method(place)]),
        style: body(12, color: C.muted, height: 1.5),
      ),
    ]);
  }

  String _method(Place p) => switch (p.region) {
        'gulf' => tr('উম্মুল কুরা পদ্ধতি'),
        'mwl' => tr('মুসলিম ওয়ার্ল্ড লিগ পদ্ধতি'),
        'na' => tr('ISNA পদ্ধতি'),
        _ => tr('করাচি পদ্ধতি (১৮°)'),
      };

  /// পরের ওয়াক্ত, its time, how long until it, and a thin line of the way there.
  Widget _nextCard(DateTime now, Place place, SunTimes t) {
    final friday = now.weekday == DateTime.friday;
    final all = [(tr('ফজর'), t.fajr), (friday ? tr('জুমা') : tr('জোহর'), t.dhuhr), (tr('আসর'), t.asr), (tr('মাগরিব'), t.maghrib), (tr('এশা'), t.isha)];
    final idx = all.indexWhere((p) => p.$2.isAfter(now));
    final tomorrow = sunTimes(now.add(const Duration(days: 1)), place);
    final yesterday = sunTimes(now.subtract(const Duration(days: 1)), place);
    final next = idx >= 0 ? all[idx] : (tr('ফজর'), tomorrow.fajr);
    final from = idx > 0 ? all[idx - 1].$2 : (idx == 0 ? yesterday.isha : t.isha);
    final left = next.$2.difference(now);
    final done = (now.difference(from).inSeconds / next.$2.difference(from).inSeconds).clamp(0.0, 1.0);
    return Panel(
      key: const Key('ibadah-next'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('পরের ওয়াক্ত'), style: body(12.5, color: C.muted)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(next.$1, style: display(26, weight: 600, height: 1.2)),
          const Spacer(),
          Text(_clock(next.$2), style: display(26, weight: 600, height: 1.2)),
        ]),
        const SizedBox(height: 4),
        Text(trf('আর {0} বাকি', [_span(left)]), style: body(13.5, weight: FontWeight.w600, color: C.green)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: done, minHeight: 3, backgroundColor: C.surface2, valueColor: AlwaysStoppedAnimation(C.green)),
        ),
      ]),
    );
  }

  Widget _waqtRow(String name, IconData icon, DateTime at, {required bool now, DateTime? until}) {
    return Container(
      key: Key('ibadah-waqt-$name'),
      color: now ? C.greenTint.withValues(alpha: 0.55) : null,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        SizedBox(width: 28, child: Icon(icon, size: 22, color: now ? C.green : C.muted2)),
        const SizedBox(width: 12),
        Expanded(
          child: Row(children: [
            Text(name, style: body(15.5, weight: now ? FontWeight.w600 : FontWeight.w500, color: now ? C.green : C.ink)),
            if (now) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: C.green)),
                child: Text(tr('এখন'), style: body(11, weight: FontWeight.w600, color: C.green)),
              ),
            ],
          ]),
        ),
        Text(bnTime(at.hour, at.minute), style: body(15.5, weight: FontWeight.w600, color: now ? C.green : C.ink)),
      ]),
    );
  }

  Widget _sunRow(String name, IconData icon, DateTime at, String note) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          SizedBox(width: 28, child: Icon(icon, size: 19, color: C.muted)),
          const SizedBox(width: 12),
          Expanded(child: Text('$name · $note', style: body(13, color: C.muted))),
          Text(bnTime(at.hour, at.minute), style: body(13.5, color: C.muted)),
        ]),
      );

  // ── সেহরি ও ইফতার ──

  Widget _fasting(Brain brain, DateTime now, Place place) {
    final today = DateTime(now.year, now.month, now.day);
    final t = sunTimes(today, place);
    final hj = hijriDate(today, adjust: brain.hijriShift);
    // This Ramadan, or the next one.
    var start = today;
    if (hj.isRamadan) {
      start = today.subtract(Duration(days: hj.day - 1));
    } else {
      for (var i = 1; i < 400; i++) {
        final d = today.add(Duration(days: i));
        final h = hijriDate(d, adjust: brain.hijriShift);
        if (h.isRamadan && h.day == 1) {
          start = d;
          break;
        }
      }
    }
    final days = <DateTime>[];
    for (var d = start; hijriDate(d, adjust: brain.hijriShift).isRamadan; d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    final ramadanYear = hijriDate(start, adjust: brain.hijriShift).year;
    final toStart = start.difference(today).inDays;
    // Each the next to come: past today's sehri, tomorrow's; past iftar, tomorrow's.
    final tomorrow = sunTimes(today.add(const Duration(days: 1)), place);
    final sehriNext = now.isBefore(t.sehriEnd) ? t.sehriEnd : tomorrow.sehriEnd;
    final iftarNext = now.isBefore(t.maghrib) ? t.maghrib : tomorrow.maghrib;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 24), children: [
      Panel(
        key: const Key('ibadah-fast-today'),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _half(Icons.nightlight_outlined, sehriNext.day != today.day ? tr('কাল সেহরি শেষ') : tr('সেহরির শেষ সময়'), sehriNext)),
            VerticalDivider(width: 1, color: C.line),
            Expanded(child: _half(Icons.wb_twilight_rounded, iftarNext.day != today.day ? tr('আগামীকাল ইফতার') : tr('আজ ইফতার'), iftarNext)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (!hj.isRamadan)
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Icon(Icons.dark_mode_outlined, size: 22, color: C.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trf('রমজান শুরু হতে আর {0} দিন', [bnDigits(toStart)]), key: const Key('ibadah-ramadan-in'), style: body(14.5, weight: FontWeight.w600)),
                Text(trf('আনুমানিক {0}, {1} · চাঁদ দেখার ওপর এক দিন আগে-পরে হতে পারে', [weekdayName(start), fullDate(start)]), style: body(12, color: C.muted, height: 1.4)),
              ]),
            ),
          ]),
        )
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Icon(Icons.dark_mode_outlined, size: 22, color: C.green),
            const SizedBox(width: 12),
            Expanded(child: Text(trf('আজ {0} রমজান', [bnDigits(hj.day)]), style: body(14.5, weight: FontWeight.w600))),
          ]),
        ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(trf('রমজান {0} · সেহরি ও ইফতারের সময়সূচি', [bnDigits(ramadanYear)]), style: body(14, weight: FontWeight.w600)),
      ),
      Panel(
        key: const Key('ibadah-timetable'),
        child: Column(children: [
          _tableRow(tr('রোজা'), tr('তারিখ'), tr('সেহরি'), tr('ইফতার'), head: true),
          for (final (i, d) in days.indexed) ...[
            Divider(height: 1, color: C.line),
            Builder(builder: (_) {
              final s = sunTimes(d, place);
              return _tableRow(bnDigits(i + 1), '${shortDate(d)}, ${weekdayShort(d)}', _clock(s.sehriEnd), _clock(s.maghrib), today: d == today, friday: d.weekday == DateTime.friday);
            }),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Text(
        trf('{0} অনুযায়ী আনুমানিক সময়। সেহরির শেষ সময় ফজরের ৫ মিনিট আগে; ইফতার মাগরিবের সময়ে।', [place.label]),
        style: body(12, color: C.muted, height: 1.5),
      ),
    ]);
  }

  Widget _half(IconData icon, String label, DateTime at) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: C.green),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted))),
          ]),
          const SizedBox(height: 6),
          Text(bnTime(at.hour, at.minute), style: display(22, weight: 600, height: 1.2)),
        ]),
      );

  Widget _tableRow(String n, String date, String sehri, String iftar, {bool head = false, bool today = false, bool friday = false}) {
    final style = head ? body(12, color: C.muted, weight: FontWeight.w500) : body(13.5, weight: today ? FontWeight.w700 : FontWeight.w500, color: today ? C.green : C.ink);
    return Container(
      color: today ? C.greenTint.withValues(alpha: 0.55) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        SizedBox(width: 40, child: Text(n, style: style)),
        Expanded(child: Text(date, style: head ? style : style.copyWith(color: today ? C.green : (friday ? C.green : C.muted2)))),
        SizedBox(width: 64, child: Text(sehri, textAlign: TextAlign.right, style: style)),
        SizedBox(width: 64, child: Text(iftar, textAlign: TextAlign.right, style: style)),
      ]),
    );
  }

  /// "৪:৫৫" without the part of the day.
  String _clock(DateTime x) => bnTime(x.hour, x.minute).replaceAll(RegExp(r'^(?:ভোর|সকাল|দুপুর|বিকেল|সন্ধ্যা|রাত)\s*'), '').replaceAll('টা', ':০০');

  /// "১ ঘণ্টা ২০ মিনিট".
  String _span(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return trf('{0} মিনিট', [bnDigits(m < 1 ? 1 : m)]);
    if (m == 0) return trf('{0} ঘণ্টা', [bnDigits(h)]);
    return trf('{0} ঘণ্টা {1} মিনিট', [bnDigits(h), bnDigits(m)]);
  }
}
