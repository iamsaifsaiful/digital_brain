import 'package:flutter/services.dart';

/// A Google Play subscription this Google account owns on this phone.
class PlaySub {
  const PlaySub(this.product, this.token, {this.acknowledged = false});
  final String product;
  final String token;
  final bool acknowledged;
}

/// What happened when the user tried to buy.
class PlayBuy {
  const PlayBuy.bought(PlaySub this.sub) : error = null, cancelled = false;
  const PlayBuy.cancelled() : sub = null, error = null, cancelled = true;
  const PlayBuy.failed(String this.error) : sub = null, cancelled = false;
  final PlaySub? sub;
  final String? error;
  final bool cancelled;
}

/// Google Play Billing (PlayBilling.kt). Only the Play app sells; the
/// purchase is checked by our server with Google before Premium turns on.
abstract class BillingSource {
  /// Play's own price for each product ('৳৯৯' or the user's currency); empty when Play is not there.
  Future<Map<String, String>> prices(List<String> products);

  /// Opens Google Play's buy sheet for [product].
  /// [account] is a hash of the member's account, so Play keeps the
  /// purchase with them (never the email itself).
  Future<PlayBuy> buy(String product, String account);

  /// Subscriptions this phone's Play account owns now (restore on a new phone).
  Future<List<PlaySub>> owned();
}

class PlayBilling implements BillingSource {
  static const _ch = MethodChannel('my_assistant/billing');

  @override
  Future<Map<String, String>> prices(List<String> products) async {
    try {
      final m = await _ch.invokeMapMethod<String, String>('prices', {'products': products});
      return m ?? const {};
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<PlayBuy> buy(String product, String account) async {
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('buy', {'product': product, 'account': account});
      if (m == null) return const PlayBuy.failed('Google Play খোলা গেল না');
      return switch (m['result']) {
        'bought' => PlayBuy.bought(PlaySub('${m['product']}', '${m['token']}', acknowledged: m['acknowledged'] == true)),
        'cancelled' => const PlayBuy.cancelled(),
        'pending' => const PlayBuy.failed('পেমেন্ট এখনো শেষ হয়নি — শেষ হলে প্রিমিয়াম নিজে থেকেই চালু হবে'),
        'owned' => const PlayBuy.failed('এই Google অ্যাকাউন্টে প্রিমিয়াম আগেই কেনা আছে — “আগে কেনা প্রিমিয়াম ফিরিয়ে আনুন” চাপুন'),
        _ => PlayBuy.failed('${m['message'] ?? 'Google Play-তে কেনা হয়নি — পরে আবার চেষ্টা করুন'}'),
      };
    } catch (_) {
      return const PlayBuy.failed('Google Play-তে কেনা হয়নি — পরে আবার চেষ্টা করুন');
    }
  }

  @override
  Future<List<PlaySub>> owned() async {
    try {
      final list = await _ch.invokeListMethod<Map<Object?, Object?>>('owned');
      return [
        for (final m in list ?? const <Map<Object?, Object?>>[])
          if ('${m['token'] ?? ''}'.isNotEmpty) PlaySub('${m['product']}', '${m['token']}', acknowledged: m['acknowledged'] == true),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// No Google Play (the downloaded APK, tests by default).
class FakeBilling implements BillingSource {
  FakeBilling({this.priceList = const {}});
  Map<String, String> priceList;
  PlayBuy next = const PlayBuy.cancelled();
  List<PlaySub> have = [];
  final bought = <String>[];
  final accounts = <String>[];

  @override
  Future<Map<String, String>> prices(List<String> products) async => {for (final p in products) if (priceList[p] != null) p: priceList[p]!};

  @override
  Future<PlayBuy> buy(String product, String account) async {
    bought.add(product);
    accounts.add(account);
    final s = next.sub;
    if (s != null) have = [...have.where((h) => h.product != s.product), s];
    return next;
  }

  @override
  Future<List<PlaySub>> owned() async => have;
}
