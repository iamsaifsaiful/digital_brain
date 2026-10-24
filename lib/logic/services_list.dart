// Well-known sites and apps for the password form (owner, 24 Oct): tap one
// and its name and address are filled in. Shown as a letter on the
// service's colour — not the company's logo.
import 'dart:ui' show Color;

import '../models/models.dart' show VaultKind;
import 'parser.dart' show normalize;

class KnownService {
  const KnownService(this.name, this.address, this.kind, this.color, {this.aliases = const []});
  final String name;
  final String address;
  final VaultKind kind;
  final Color color;
  final List<String> aliases;
  String get letter => name.characters0;
}

extension on String {
  String get characters0 => isEmpty ? '' : substring(0, 1).toUpperCase();
}

const knownServices = [
  KnownService('Facebook', 'facebook.com', VaultKind.app, Color(0xFF1877F2), aliases: ['ফেসবুক', 'fb']),
  KnownService('Messenger', 'messenger.com', VaultKind.app, Color(0xFF0084FF), aliases: ['মেসেঞ্জার']),
  KnownService('WhatsApp', 'whatsapp.com', VaultKind.app, Color(0xFF25D366), aliases: ['হোয়াটসঅ্যাপ', 'হোয়াটসআপ']),
  KnownService('Gmail', 'gmail.com', VaultKind.email, Color(0xFFEA4335), aliases: ['জিমেইল', 'google', 'গুগল']),
  KnownService('Instagram', 'instagram.com', VaultKind.app, Color(0xFFC13584), aliases: ['ইনস্টাগ্রাম']),
  KnownService('YouTube', 'youtube.com', VaultKind.app, Color(0xFFFF0000), aliases: ['ইউটিউব']),
  KnownService('TikTok', 'tiktok.com', VaultKind.app, Color(0xFF111111), aliases: ['টিকটক']),
  KnownService('X (Twitter)', 'x.com', VaultKind.app, Color(0xFF111111), aliases: ['twitter', 'টুইটার']),
  KnownService('LinkedIn', 'linkedin.com', VaultKind.website, Color(0xFF0A66C2), aliases: ['লিংকডইন']),
  KnownService('Telegram', 'telegram.org', VaultKind.app, Color(0xFF229ED9), aliases: ['টেলিগ্রাম']),
  KnownService('imo', 'imo.im', VaultKind.app, Color(0xFF1E88E5), aliases: ['ইমো']),
  KnownService('Snapchat', 'snapchat.com', VaultKind.app, Color(0xFFE6C700), aliases: ['স্ন্যাপচ্যাট']),
  KnownService('bKash', 'bkash.com', VaultKind.bank, Color(0xFFE2136E), aliases: ['বিকাশ']),
  KnownService('Nagad', 'nagad.com.bd', VaultKind.bank, Color(0xFFEC1C24), aliases: ['নগদ']),
  KnownService('Rocket', 'dutchbanglabank.com', VaultKind.bank, Color(0xFF8E24AA), aliases: ['রকেট']),
  KnownService('Daraz', 'daraz.com.bd', VaultKind.website, Color(0xFFF57224), aliases: ['দারাজ']),
];

/// The known service a saved name stands for, if any.
KnownService? knownServiceOf(String name) {
  final n = normalize(name);
  if (n.isEmpty) return null;
  for (final s in knownServices) {
    if ([s.name, s.address, ...s.aliases].any((x) => normalize(x) == n || n.startsWith('${normalize(x)} '))) return s;
  }
  return null;
}
