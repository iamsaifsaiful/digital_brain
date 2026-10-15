import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Opens the phone's dialer, SMS app or WhatsApp. The user still presses
/// call/send there; nothing is sent without them.
abstract class Launcher {
  /// False when no app could open it.
  Future<bool> open(Via via, String phone, {String text = ''});

  /// A web or map link in its own app.
  Future<bool> openUrl(Uri uri);
}

/// A place in Google Maps (the app if installed, else the browser).
Uri mapUri(String place) => Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place.trim())}');

/// "01712-345678" → "01712345678"; "+880 1712…" → "+8801712…".
String cleanPhone(String phone) {
  final p = phone.trim();
  final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
  return p.startsWith('+') ? '+$digits' : digits;
}

/// The number in the international form WhatsApp links need (no plus).
String whatsappNumber(String phone) {
  var d = cleanPhone(phone).replaceAll('+', '');
  if (d.startsWith('0') && d.length == 11) d = '88$d';
  if (d.startsWith('1') && d.length == 10) d = '880$d';
  return d;
}

Uri launchUri(Via via, String phone, {String text = ''}) {
  final p = cleanPhone(phone);
  return switch (via) {
    Via.call => Uri.parse('tel:$p'),
    Via.sms => Uri.parse(text.isEmpty ? 'sms:$p' : 'sms:$p?body=${Uri.encodeComponent(text)}'),
    Via.whatsapp => Uri.parse('https://wa.me/${whatsappNumber(p)}${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}'),
  };
}

class DeviceLauncher implements Launcher {
  @override
  Future<bool> open(Via via, String phone, {String text = ''}) async {
    try {
      return await launchUrl(launchUri(via, phone, text: text), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('launch failed');
      return false;
    }
  }

  @override
  Future<bool> openUrl(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('launch failed');
      return false;
    }
  }
}

class FakeLauncher implements Launcher {
  final opened = <Uri>[];
  bool works = true;

  @override
  Future<bool> open(Via via, String phone, {String text = ''}) async {
    opened.add(launchUri(via, phone, text: text));
    return works;
  }

  @override
  Future<bool> openUrl(Uri uri) async {
    opened.add(uri);
    return works;
  }
}
