// DIAGNOSTIC BUILD ONLY (branch diag-noads): AdMob taken out to find what
// closes the 2.65.0 preview on the owner's phone. Never merged.
import 'package:flutter/widgets.dart';

const realAds = false;
const admobBanner = '';
const admobFull = '';

class Ads {
  static Future<bool> start() async => false;
  static Future<bool> privacyChoiceNeeded() async => false;
  static Future<void> changePrivacyChoice() async {}
  static Future<bool> showFull() async => false;
}

class AdMobBanner extends StatelessWidget {
  const AdMobBanner({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
