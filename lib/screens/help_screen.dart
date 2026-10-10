import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_shell.dart';

class _Skill {
  const _Skill(this.icon, this.title, this.what, this.say);
  final IconData icon;
  final String title;
  final String what;

  /// Things to say to the assistant.
  final List<String> say;
}

const _skills = [
  _Skill(Icons.mic_none_rounded, 'মুখে বলুন, সহকারী সামলাবে', 'নিচের মাঝখানের মাইক চাপুন, স্বাভাবিকভাবে বলুন। একসাথে কয়েকটা কথাও বলা যায়।',
      ['রবিনকে ৫ হাজার টাকা দিলাম আর কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও', 'তুমি কী কী পারো?']),
  _Skill(Icons.checklist_rounded, 'কাজের তালিকা', 'দিনের কাজ একটা একটা করে বলুন; “শেষ” বললে সব একসাথে তালিকায় ওঠে। টিক দিলে কাজ শেষ।',
      ['আজকের কাজের তালিকা', 'কাল ব্যাংকে যেতে হবে', 'ব্যাংকের কাজ হয়ে গেছে', 'আজ আমার কী কী আছে?']),
  _Skill(Icons.notifications_active_outlined, 'অ্যালার্মের মতো রিমাইন্ডার', 'ঠিক সময়ে বাজে, ফোন লক থাকলেও। ৫/১০ মিনিট পরে আবার মনে করানো যায়। নিজের পছন্দের রিংটোন।',
      ['বিকেল ৪টায় ক্লায়েন্ট মিটিং মনে করিয়ে দিও', 'প্রতিদিন রাত ১০টায় ওষুধ', 'প্রতি মাসের ৫ তারিখে দোকান ভাড়া', 'প্রতি ৩০ মিনিটে পানি খাওয়া']),
  _Skill(Icons.swap_horiz_rounded, 'ধার-দেনা ও কাস্টমারের বাকি', 'কে কত পাবে, কাকে কত দিতে হবে — নাম ও মোবাইল নম্বরসহ। এক চাপে তাগাদার মেসেজ।',
      ['করিম ৫০০ টাকার মাল বাকিতে নিল', 'রহিমের কাছ থেকে ২ হাজার ধার নিলাম', 'আমি কার কাছে কত পাব?']),
  _Skill(Icons.account_balance_wallet_outlined, 'আয়-ব্যয় ও প্রজেক্ট', 'নিজের খরচ আর আয় খাত ধরে; মাসের ব্যালেন্স। প্রতিটা প্রজেক্টের আলাদা হিসাব।',
      ['বাজারে ৫০০ টাকা খরচ হলো', 'বেতন পেলাম ৩০ হাজার', 'রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার', 'এই মাসে কত খরচ হলো?']),
  _Skill(Icons.call_outlined, 'ফোন, SMS, WhatsApp', 'নাম বললেই ফোন বা মেসেজ খুলে দেয়; একই নামে কয়েকজন থাকলে জিজ্ঞেস করে নেয়। ফোনবুকের সব নম্বর এক ক্লিকে আনা যায়।',
      ['রহিমকে ফোন দাও', 'করিমকে মেসেজ দাও যে মাল পাঠিয়েছি', 'রহিমের নম্বর ০১৭… রাখো']),
  _Skill(Icons.sticky_note_2_outlined, 'নোট ও নিজের বিভাগ', 'যা মনে রাখতে চান বলুন; নতুন বিষয় বললে নতুন বিভাগ খুলে যায়।',
      ['মনে রাখো: গাড়ির কাগজ আলমারিতে', 'দোকানের মাল', 'গাড়ির কাগজ কোথায় রেখেছি?']),
  _Skill(Icons.key_rounded, 'পাসওয়ার্ড ভল্ট', 'ওয়েবসাইট, অ্যাপ, Wi-Fi, ব্যাংকের লগইন তালাবদ্ধ থাকে; দেখতে আঙুলের ছাপ বা PIN লাগে। কখনো জোরে পড়া হয় না।',
      ['ফেসবুকের পাসওয়ার্ড দেখাও']),
  _Skill(Icons.cloud_download_outlined, 'ব্যাকআপ', 'সব তথ্য একটা তালাবদ্ধ ফাইলে; ফোন বদলালে ফিরিয়ে আনা যায়।', []),
];

/// "অ্যাপ দিয়ে কী কী করা যায়": every feature with things to say.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            const TopBar(title: 'কী কী করা যায়'),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                Text('বাঁকা হরফের কথাগুলো মাইকে হুবহু বলে দেখুন।', style: body(14, color: C.muted)),
                const SizedBox(height: 12),
                for (final s in _skills) ...[
                  Panel(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
                          child: Icon(s.icon, color: C.green, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.title, style: body(16, weight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 8),
                      Text(s.what, style: body(14, color: C.muted2, height: 1.5)),
                      if (s.say.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final x in s.say)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('“$x”', style: body(14, color: C.greenDark).copyWith(fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                PrimaryButton(label: 'মাইকে বলে দেখুন', icon: Icons.mic_none_rounded, onPressed: () => openVoice(context)),
              ]),
            ),
          ]),
        ),
      );
}
