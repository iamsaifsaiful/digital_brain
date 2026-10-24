/// The light over the home picture through the day (owner, 24 Oct night):
/// dawn, morning, noon, afternoon, the golden hour, sunset, evening and
/// night, worked out from the district's sunrise and sunset. The picture
/// is the owner's day and night painting; [SkyLight.night] mixes the night
/// one over the day one, [SkyLight.tint] colours the light, [SkyLight.dim]
/// darkens it.
library;

import 'dart:ui' show Color, lerpDouble;

class SkyLight {
  const SkyLight({required this.night, required this.tint, required this.tintAmount, required this.dim, required this.phase});

  /// 0 = the day picture, 1 = the night picture.
  final double night;
  final Color tint;

  /// How strongly [tint] colours the picture (0–1).
  final double tintAmount;

  /// How much darker (0–1).
  final double dim;

  /// 'night', 'dawn', 'sunrise', 'morning', 'noon', 'afternoon', 'golden', 'sunset' or 'evening'.
  final String phase;
}

class _Key {
  const _Key(this.minutes, this.night, this.tint, this.amount, this.dim, this.phase);
  final double minutes;
  final double night;
  final Color tint;
  final double amount;
  final double dim;
  final String phase;
}

/// The light at [now], for a day whose sun rises at [sunrise] and sets at [sunset].
SkyLight skyLight(DateTime now, DateTime sunrise, DateTime sunset) {
  double at(DateTime t) => t.hour * 60 + t.minute + t.second / 60;
  final rise = at(sunrise), set = at(sunset), noon = (rise + set) / 2;
  final keys = [
    _Key(rise - 80, 1, const Color(0xFF1B2A6B), 0, 0, 'night'),
    _Key(rise - 30, 0.72, const Color(0xFF9A5CB8), 0.60, 0.08, 'dawn'),
    _Key(rise + 10, 0.10, const Color(0xFFFF8A55), 0.62, 0.02, 'sunrise'),
    _Key(rise + 90, 0, const Color(0xFFFFD08A), 0.22, 0, 'morning'),
    _Key(noon, 0, const Color(0xFFEAF4FF), 0.05, 0, 'noon'),
    _Key(set - 150, 0, const Color(0xFFFFD49A), 0.26, 0, 'afternoon'),
    _Key(set - 45, 0, const Color(0xFFFF9A3C), 0.62, 0, 'golden'),
    _Key(set, 0.22, const Color(0xFFF0603C), 0.72, 0.06, 'sunset'),
    _Key(set + 25, 0.62, const Color(0xFF8A4AA8), 0.58, 0.10, 'evening'),
    _Key(set + 70, 1, const Color(0xFF1B2A6B), 0, 0, 'night'),
  ];
  final m = at(now);
  if (m <= keys.first.minutes || m >= keys.last.minutes) {
    return SkyLight(night: 1, tint: keys.first.tint, tintAmount: 0, dim: 0, phase: 'night');
  }
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i], b = keys[i + 1];
    if (m < a.minutes || m > b.minutes) continue;
    final f = b.minutes == a.minutes ? 0.0 : (m - a.minutes) / (b.minutes - a.minutes);
    return SkyLight(
      night: lerpDouble(a.night, b.night, f)!,
      tint: Color.lerp(a.tint, b.tint, f)!,
      tintAmount: lerpDouble(a.amount, b.amount, f)!,
      dim: lerpDouble(a.dim, b.dim, f)!,
      phase: f < 0.5 ? a.phase : b.phase,
    );
  }
  return SkyLight(night: 1, tint: keys.first.tint, tintAmount: 0, dim: 0, phase: 'night');
}
