/// A last guard on everything sent to the AI: phone, card, account and ID
/// numbers (any run of 10 or more digits, spaces and dashes allowed) and
/// e-mail addresses are replaced before the text leaves the phone — on top
/// of the rules that already keep passwords, the vault, PINs and secret
/// notes out.
library;

final _longNumber = RegExp(r'\+?[0-9০-৯](?:[\s\-]?[0-9০-৯]){9,}');
final _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

String redactForAi(String text) => text.replaceAll(_email, '[ইমেইল]').replaceAll(_longNumber, '[নম্বর]');
