/// Directions for the compass page: the eight directions in words, and the
/// qibla (the Kaaba in Makkah) from a place, by the great circle.
library;

import 'dart:math' as math;

import 'bn.dart';
import 'lang.dart';

const _kaabaLat = 21.422487;
const _kaabaLon = 39.826206;

/// Degrees clockwise from true north from ([lat], [lon]) to the Kaaba.
double qiblaFrom(double lat, double lon) {
  double rad(double x) => x * math.pi / 180;
  final p1 = rad(lat), p2 = rad(_kaabaLat), dl = rad(_kaabaLon - lon);
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

const _eight = ['উত্তর', 'উত্তর-পূর্ব', 'পূর্ব', 'দক্ষিণ-পূর্ব', 'দক্ষিণ', 'দক্ষিণ-পশ্চিম', 'পশ্চিম', 'উত্তর-পশ্চিম'];

/// "উত্তর-পূর্ব" for 45°.
String directionName(double degrees) => tr(_eight[(((degrees % 360) + 22.5) ~/ 45) % 8]);

/// The way from [from] to [to], the shorter way round: + is clockwise (to the right).
double turnTo(double from, double to) {
  final d = (to - from) % 360;
  return d > 180 ? d - 360 : d;
}

/// "২৭৮°"
String degreesText(double d) => '${bnDigits(d.round() % 360)}°';

/// "কিবলা কোন দিকে?" — said from [place] (its name), with the bearing.
String qiblaSaid(String place, double lat, double lon) {
  final q = qiblaFrom(lat, lon);
  return trf('{0} থেকে কিবলা {1} দিকে — উত্তর থেকে ঘড়ির কাঁটার দিকে {2}। কম্পাস খুললে ফোন ঘুরিয়ে তীর মিলিয়ে নিতে পারবেন।', [place, directionName(q), degreesText(q)]);
}
