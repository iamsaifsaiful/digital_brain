import 'dart:async';

import 'package:flutter/services.dart';

/// Where the top of the phone points: degrees from magnetic north, and the
/// sensor's own trust in it (0 = needs a figure-8, 3 = good).
class Heading {
  const Heading(this.degrees, {this.accuracy = 3});
  final double degrees;
  final int accuracy;
  bool get shaky => accuracy <= 1;
}

/// The phone's compass. The stream gives null when the phone has no sensor for it.
abstract class CompassSource {
  Stream<Heading?> headings();
}

class DeviceCompass implements CompassSource {
  static const _ch = EventChannel('my_assistant/compass');

  @override
  Stream<Heading?> headings() => _ch.receiveBroadcastStream().map<Heading?>((e) {
        final m = (e as Map).cast<Object?, Object?>();
        if (m['none'] == true) return null;
        return Heading((m['heading'] as num).toDouble(), accuracy: (m['accuracy'] as num?)?.toInt() ?? 3);
      }).handleError((Object _) {});
}

/// Tests: headings pushed by hand.
class FakeCompass implements CompassSource {
  final _c = StreamController<Heading?>.broadcast();
  void point(Heading? h) => _c.add(h);

  @override
  Stream<Heading?> headings() => _c.stream;
}
