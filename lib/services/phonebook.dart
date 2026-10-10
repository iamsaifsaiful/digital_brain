import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A name and number from the phone's own contacts.
class PhoneContact {
  const PhoneContact(this.name, this.phone);
  final String name;
  final String phone;
}

/// The phone book, read only when the user asks ("ফোনবুক থেকে আনুন").
/// Nothing from it ever leaves the phone.
abstract class Phonebook {
  /// Null when the user did not allow it.
  Future<List<PhoneContact>?> readAll();
}

class DevicePhonebook implements Phonebook {
  static const _ch = MethodChannel('my_assistant/contacts');

  @override
  Future<List<PhoneContact>?> readAll() async {
    try {
      final r = await _ch.invokeListMethod<Object?>('readAll');
      if (r == null) return null;
      return [
        for (final m in r)
          if (m is Map) PhoneContact('${m['name'] ?? ''}', '${m['phone'] ?? ''}'),
      ];
    } catch (e) {
      debugPrint('Phonebook unavailable: $e');
      return null;
    }
  }
}

/// For tests.
class FakePhonebook implements Phonebook {
  FakePhonebook([this.contacts = const []]);
  List<PhoneContact> contacts;
  bool denied = false;

  @override
  Future<List<PhoneContact>?> readAll() async => denied ? null : contacts;
}
