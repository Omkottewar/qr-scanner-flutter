import 'package:shared_preferences/shared_preferences.dart';

// Persisted "there's a live Razorpay order out in the wild" marker.
// Written to disk the moment we get an order_id back from the backend
// so an OS kill mid-checkout doesn't leave the customer with a debited
// card and no QR. On next app boot main.dart reads this and asks
// GET /payments/status/:orderId to figure out what happened.
abstract final class PendingOrderStore {
  static const _kOrderId = 'pending_order_id';
  static const _kPurpose = 'pending_order_purpose'; // 'qr_create' | 'qr_renew'
  static const _kQrId = 'pending_order_qr_id';       // renewal only
  static const _kCreatedAt = 'pending_order_created_at';

  /// Called when a Razorpay order is created and we're about to open
  /// the checkout modal. Overwrites any prior pending order — only one
  /// can be in-flight at a time from the user's perspective.
  static Future<void> save({
    required String orderId,
    required String purpose,
    int? qrId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOrderId, orderId);
    await p.setString(_kPurpose, purpose);
    if (qrId != null) {
      await p.setInt(_kQrId, qrId);
    } else {
      await p.remove(_kQrId);
    }
    await p.setInt(_kCreatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Called after the payment resolves (success OR final failure) so
  /// we don't re-check it on the next boot.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOrderId);
    await p.remove(_kPurpose);
    await p.remove(_kQrId);
    await p.remove(_kCreatedAt);
  }

  /// Returns the pending order id + purpose if a checkout was left
  /// hanging, otherwise null. Auto-clears rows older than 24h so a
  /// long-forgotten pending marker doesn't keep popping the recovery
  /// dialog every launch.
  static Future<PendingOrder?> read() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_kOrderId);
    if (id == null || id.isEmpty) return null;
    final createdAt = p.getInt(_kCreatedAt) ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - createdAt;
    if (ageMs > const Duration(hours: 24).inMilliseconds) {
      await clear();
      return null;
    }
    return PendingOrder(
      orderId: id,
      purpose: p.getString(_kPurpose) ?? 'qr_create',
      qrId: p.getInt(_kQrId),
    );
  }
}

class PendingOrder {
  const PendingOrder({
    required this.orderId,
    required this.purpose,
    this.qrId,
  });
  final String orderId;
  final String purpose;
  final int? qrId;
}
