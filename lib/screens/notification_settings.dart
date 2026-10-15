import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// সেটিংস › নোটিফিকেশন: every kind of note the assistant sends by itself,
/// each with its own switch, and the two rules that keep them welcome —
/// quiet hours and a daily limit. Alarms and the user's own reminders are
/// outside these rules and always ring on time.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);

    Widget sw(IconData icon, String title, String sub, bool v, ValueChanged<bool> on, {Widget? extra}) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: C.muted2, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15)),
                Text(sub, style: body(12, color: C.muted)),
                if (extra != null) extra,
              ]),
            ),
            Switch(value: v, onChanged: on),
          ]),
        );

    Widget timeLink(int minutes, ValueChanged<int> set, {String? label}) => InkWell(
          onTap: () async {
            final m = await askTime(context, minutes);
            if (m != null) set(m);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(trf('{0}: {1} · বদলান', [label ?? tr('সময়'), minutesText(minutes)]), style: body(13, weight: FontWeight.w600, color: C.green)),
          ),
        );

    final prayers = {for (final x in brain.text('prayer_set').split(',')) if (x.trim().isNotEmpty) x.trim()};
    Future<void> togglePrayer(String k) async {
      final next = {...prayers};
      next.contains(k) ? next.remove(k) : next.add(k);
      await brain.setPref('prayer_set', next.join(','));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('নোটিফিকেশন')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
              InfoBanner(
                icon: Icons.notifications_active_outlined,
                text: tr('সহকারী নিজে থেকে শুধু কাজের কথাই জানায় — দিনে অল্প কয়েকটা, রাতে চুপ। যেটা লাগবে না, বন্ধ করে দিন। অ্যালার্ম আর আপনার রাখা রিমাইন্ডার এই নিয়মের বাইরে, সেগুলো সবসময় ঠিক সময়ে বাজবে।'),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('প্রতিদিন')),
              Panel(
                child: Rows(children: [
                  sw(Icons.wb_sunny_outlined, tr('সকালের সারাংশ'), tr('আজকের রিমাইন্ডার, কাজ, ছুটি আর বিশেষ দিন'), brain.morningOn, (v) => brain.setPref('morning_on', v),
                      extra: brain.morningOn ? timeLink(brain.morningAt, (m) => brain.setPref('morning_at', m)) : null),
                  sw(Icons.nights_stay_outlined, tr('রাতের সারাংশ'), tr('শুধু কাজ বাকি থাকলে — এক চাপে কালকে সরানো যায়'), brain.nightOn, (v) => brain.setPref('night_on', v),
                      extra: brain.nightOn ? timeLink(brain.nightAt, (m) => brain.setPref('night_at', m)) : null),
                ]),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('কাজের কথা')),
              Panel(
                child: Rows(children: [
                  sw(Icons.tips_and_updates_outlined, tr('নিজে থেকে মনে করানো'), tr('পাওনা ৩০ দিন পার, বিলের শেষ দিন পরশু, কাগজের মেয়াদ, ওষুধ ফুরিয়ে আসা'), brain.nudgesOn,
                      (v) => brain.setPref('nudges_on', v)),
                  sw(Icons.local_fire_department_outlined, tr('অভ্যাসের ধারা'), tr('টানা কয়েক দিন করছেন, আজ টিক না দিলে রাত ৮টায় একবার'), brain.flag('n_streak', true),
                      (v) => brain.setPref('n_streak', v)),
                  sw(Icons.insights_outlined, tr('সাপ্তাহিক হিসাব'), tr('শনিবার সকালে: গত সপ্তাহের খরচ, শেষ আর বাকি কাজ'), brain.flag('n_weekly', true), (v) => brain.setPref('n_weekly', v)),
                ]),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('দিন ও উৎসব')),
              Panel(
                child: Rows(children: [
                  sw(Icons.mosque_outlined, tr('জুমার দিন'), tr('শুক্রবার সকাল ১১টায় — জুমা মোবারক'), brain.flag('n_jumuah', true), (v) => brain.setPref('n_jumuah', v)),
                  sw(Icons.celebration_outlined, tr('উৎসবের শুভেচ্ছা'), tr('ঈদ, নববর্ষ, বিজয় দিবস — সেদিন সকালে'), brain.flag('n_festival', true), (v) => brain.setPref('n_festival', v)),
                  sw(Icons.health_and_safety_outlined, tr('মৌসুমি স্বাস্থ্য পরামর্শ'), tr('মাসে একবার — ডেঙ্গু, গরম, শীতের সময় কী করবেন'), brain.flag('n_health', true), (v) => brain.setPref('n_health', v)),
                  sw(Icons.waving_hand_outlined, tr('অনেক দিন না খুললে'), tr('৩ দিন অ্যাপ না খুললে শুধু একবার মনে করাবে'), brain.flag('n_comeback', true), (v) => brain.setPref('n_comeback', v)),
                ]),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('নামাজ ও রমজান')),
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('যে ওয়াক্তের সময় জানাবে'), style: body(15)),
                  Text(trf('{0} অনুযায়ী আনুমানিক সময়ে; চুপ থাকার সময়েও জানাবে', [tr(brain.district)]), style: body(12, color: C.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (k, label) in [('fajr', tr('ফজর')), ('dhuhr', tr('জোহর')), ('asr', tr('আসর')), ('maghrib', tr('মাগরিব')), ('isha', tr('এশা'))])
                      FilterChip(label: Text(label), selected: prayers.contains(k), onSelected: (_) => togglePrayer(k)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('রমজানে সেহরি ও ইফতার'), style: body(15)),
                        Text(tr('সেহরির শেষ সময়ের ৪০ মিনিট আগে, ইফতারের ১০ মিনিট আগে'), style: body(12, color: C.muted)),
                      ]),
                    ),
                    Switch(value: brain.flag('n_ramadan'), onChanged: (v) => brain.setPref('n_ramadan', v)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('বিরক্ত না করার নিয়ম')),
              Panel(
                child: Rows(children: [
                  sw(Icons.bedtime_outlined, tr('চুপ থাকার সময়'), tr('এই সময়ে আসা বার্তা সকাল পর্যন্ত অপেক্ষা করবে'), brain.flag('quiet_on', true), (v) => brain.setPref('quiet_on', v),
                      extra: brain.flag('quiet_on', true)
                          ? Wrap(spacing: 14, children: [
                              timeLink(brain.number('quiet_from', 22 * 60), (m) => brain.setPref('quiet_from', m), label: tr('শুরু')),
                              timeLink(brain.number('quiet_to', 7 * 60), (m) => brain.setPref('quiet_to', m), label: tr('শেষ')),
                            ])
                          : null),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('দিনে সর্বোচ্চ কয়টা'), style: body(15)),
                      Text(tr('সারাংশ আর নামাজের সময় বাদে; বেশি হলে কম জরুরিগুলো বাদ যায়'), style: body(12, color: C.muted)),
                      const SizedBox(height: 8),
                      SegTabs<int>(
                        items: [for (final n in [1, 2, 3, 5]) (n, bnDigits(n))],
                        value: brain.number('daily_cap', 3),
                        onChanged: (v) => brain.setPref('daily_cap', v),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
