import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../logic/pro.dart' show edition;

/// Real Google ads (AdMob) only in the Play app itself; the preview draws
/// labelled samples and the downloaded APK shows none.
const realAds = edition == 'play';

/// The Play build's ad units (its settings); Google's own test units otherwise.
const admobBanner = String.fromEnvironment('ADMOB_BANNER', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
const admobFull = String.fromEnvironment('ADMOB_FULL', defaultValue: 'ca-app-pub-3940256099942544/1033173712');

/// AdMob for the free Play app: Google's consent form first (where the law
/// asks for one), then ads — never before.
class Ads {
  static Future<bool>? _ready;
  static InterstitialAd? _full;
  static bool _loadingFull = false;

  /// Asks for consent when needed and starts AdMob. True when ads may be asked for.
  static Future<bool> start() => _ready ??= _start();

  static Future<bool> _start() async {
    if (!realAds) return false;
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      }, (_) {
        if (!done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await MobileAds.instance.initialize();
      _loadFull();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Settings › বিজ্ঞাপনের গোপনীয়তা: shown only where Google says the user must be able to change it.
  static Future<bool> privacyChoiceNeeded() async {
    if (!realAds) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  static Future<void> changePrivacyChoice() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }

  static void _loadFull() {
    if (_full != null || _loadingFull) return;
    _loadingFull = true;
    InterstitialAd.load(
      adUnitId: admobFull,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingFull = false;
          _full = ad;
        },
        onAdFailedToLoad: (_) => _loadingFull = false,
      ),
    );
  }

  /// A full-screen ad after a finished task (the app decides when — fullAdDue). False when none was ready.
  static Future<bool> showFull() async {
    if (!await start()) return false;
    final ad = _full;
    if (ad == null) {
      _loadFull();
      return false;
    }
    _full = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show();
    await closed.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    _loadFull();
    return true;
  }
}

/// A small Google banner (the free Play app); nothing until one has loaded.
class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!await Ads.start() || !mounted) return;
    // The small 320×50 banner (owner: "ছোট ব্যানার").
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: admobBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, _) => a.dispose(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(key: const Key('ad-admob'), width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad));
  }
}
