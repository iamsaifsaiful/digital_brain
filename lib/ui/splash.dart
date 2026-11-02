// The opening (owner, 2 Nov: "এপ প্রতিবার ওপেন করলে একটু সুন্দর এনিমেশন
// আসবে। এরপর লগইন পেইজ"): every cold start, the app's mark grows in, a soft
// ring opens out from it, the name rises under it — about 1.8 s — and then
// the PIN page (or home when there is no lock). Flat: no gradient, no shadow.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'theme.dart';

// (C.night: the app's dark ground, as the start page always had.)

/// Under `flutter test` the opening is skipped (every test starts the app).
final bool splashOn = !Platform.environment.containsKey('FLUTTER_TEST');

class Splash extends StatefulWidget {
  const Splash({super.key, required this.onDone});

  /// Called once the opening has played.
  final VoidCallback onDone;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  // The mark: 0–45%, grows with a little overshoot and fades in.
  late final Animation<double> _mark = CurvedAnimation(parent: _c, curve: const Interval(0, 0.45, curve: Curves.easeOutBack));
  late final Animation<double> _markFade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.3, curve: Curves.easeOut));
  // The ring: 25–85%, opens out and fades away.
  late final Animation<double> _ring = CurvedAnimation(parent: _c, curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic));
  // The name: 40–75%, rises and fades in.
  late final Animation<double> _name = CurvedAnimation(parent: _c, curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic));

  static const _markImage = AssetImage('assets/brand/app_mark.png');
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The mark decoded first (at most 400 ms), so it is there as it grows.
    precacheImage(_markImage, context).timeout(const Duration(milliseconds: 400), onTimeout: () {}).catchError((_) {}).whenComplete(() {
      if (!mounted) return;
      _c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    // The mark's own yellow (its sound bars).
    const ring = Color(0xFFF5B841);
    return Scaffold(
      key: const Key('splash'),
      backgroundColor: C.night,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: size * 1.7,
              height: size * 1.7,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                // The ring opening out.
                Opacity(
                  opacity: (1 - _ring.value).clamp(0.0, 1.0) * (_ring.value > 0 ? 0.55 : 0),
                  child: Container(
                    width: size * (1 + 1.1 * _ring.value),
                    height: size * (1 + 1.1 * _ring.value),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
                  ),
                ),
                Opacity(
                  opacity: _markFade.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * _mark.value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(size * 0.24),
                      child: const Image(image: _markImage, width: size, height: size, fit: BoxFit.cover, excludeFromSemantics: true),
                    ),
                  ),
                ),
              ]),
            ),
            Opacity(
              opacity: _name.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - _name.value)),
                child: const Text('My Assistant', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
