import 'dart:async';

import 'package:flutter/services.dart';

/// Where the phone points (top edge, or its back when held upright):
/// degrees from true north at the place given to [CompassSource.headings], and the
/// sensor's own trust in it (0 = needs a figure-8, 3 = good).
class Heading {
  const Heading(this.degrees, {this.accuracy = 3});
  final double degrees;
  final int accuracy;
  bool get shaky => accuracy <= 1;
}

/// The phone's compass. The stream gives null when the phone has no sensor for it.
abstract class CompassSource {
  /// [lat]/[lon]: where the phone is, so the magnetic declination there is
  /// taken out and 0° is true north (the qibla is worked out from true north).
  Stream<Heading?> headings({double? lat, double? lon});
}

class DeviceCompass implements CompassSource {
  static const _ch = EventChannel('my_assistant/compass');

  @override
  Stream<Heading?> headings({double? lat, double? lon}) => _ch.receiveBroadcastStream({'lat': lat, 'lon': lon}).map<Heading?>((e) {
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
  Stream<Heading?> headings({double? lat, double? lon}) => _c.stream;
}
