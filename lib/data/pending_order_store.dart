import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// Persisted "there's a live Razorpay order out in the wild" marker.
// Written to disk the moment we get an order_id back from the backend
// so an OS kill mid-checkout doesn't leave the customer with a debited
// card and no QR. On next app boot main.dart reads this, asks
// GET /payments/status/:orderId what happened, and finishes the job.
//
// For a new QR the filled-in form (`createBody`) is saved too, and once
// Razorpay reports success the payment id + signature are added — that
// is everything needed to call /qr/create (or /renew/verify) after a
// restart. Before this, the form only lived in memory, so a paid order
// interrupted by an app kill never produced a QR.
abstract final class PendingOrderStore {
  static const _kOrderId = 'pending_order_id';
  static const _kPurpose = 'pending_order_purpose'; // 'qr_create' | 'qr_renew'
  static const _kQrId = 'pending_order_qr_id';       // renewal only
  static const _kCreatedAt = 'pending_order_created_at';
  static const _kCreateBody = 'pending_order_create_body'; // JSON, qr_create only
  static const _kPaymentId = 'pending_order_payment_id';
  static const _kSignature = 'pending_order_signature';

  // An unpaid order is dropped after a day. A paid one (we hold the
  // payment proof) is kept for a week so a customer who doesn't reopen
  // the app straight away still gets their QR.
  static const _unpaidMaxAge = Duration(hours: 24);
  static const _paidMaxAge = Duration(days: 7);

  /// Called when a Razorpay order is created and we're about to open
  /// the checkout modal. Overwrites any prior pending order — only one
  /// can be in-flight at a time from the user's perspective.
  static Future<void> save({
    required String orderId,
    required String purpose,
    int? qrId,
    Map<String, dynamic>? createBody,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOrderId, orderId);
    await p.setString(_kPurpose, purpose);
    if (qrId != null) {
      await p.setInt(_kQrId, qrId);
    } else {
      await p.remove(_kQrId);
    }
    if (createBody != null) {
      await p.setString(_kCreateBody, jsonEncode(createBody));
    } else {
      await p.remove(_kCreateBody);
    }
    await p.remove(_kPaymentId);
    await p.remove(_kSignature);
    await p.setInt(_kCreatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Called as soon as Razorpay reports success, BEFORE calling the
  /// server, so the payment can still be redeemed after an app kill.
  /// Ignored if the stored order is a different one.
  static Future<void> savePaymentProof({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (p.getString(_kOrderId) != orderId) return;
    await p.setString(_kPaymentId, paymentId);
    await p.setString(_kSignature, signature);
  }

  /// Called after the payment resolves (success OR final failure) so
  /// we don't re-check it on the next boot.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOrderId);
    await p.remove(_kPurpose);
    await p.remove(_kQrId);
    await p.remove(_kCreatedAt);
    await p.remove(_kCreateBody);
    await p.remove(_kPaymentId);
    await p.remove(_kSignature);
  }

  /// Returns the pending order if a checkout was left hanging, otherwise
  /// null. Auto-clears expired markers (see max ages above) so a
  /// long-forgotten one doesn't keep being retried every launch.
  static Future<PendingOrder?> read() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_kOrderId);
    if (id == null || id.isEmpty) return null;

    final paymentId = p.getString(_kPaymentId);
    final signature = p.getString(_kSignature);
    final hasProof = (paymentId ?? '').isNotEmpty && (signature ?? '').isNotEmpty;

    final createdAt = p.getInt(_kCreatedAt) ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - createdAt;
    final maxAge = hasProof ? _paidMaxAge : _unpaidMaxAge;
    if (ageMs > maxAge.inMilliseconds) {
      await clear();
      return null;
    }

    Map<String, dynamic>? createBody;
    final rawBody = p.getString(_kCreateBody);
    if (rawBody != null && rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map) createBody = Map<String, dynamic>.from(decoded);
      } catch (_) {
        createBody = null;
      }
    }

    return PendingOrder(
      orderId: id,
      purpose: p.getString(_kPurpose) ?? 'qr_create',
      qrId: p.getInt(_kQrId),
      createBody: createBody,
      paymentId: paymentId,
      signature: signature,
    );
  }
}

class PendingOrder {
  const PendingOrder({
    required this.orderId,
    required this.purpose,
    this.qrId,
    this.createBody,
    this.paymentId,
    this.signature,
  });
  final String orderId;
  final String purpose;
  final int? qrId;
  /// The /qr/create form fields (qr_create only).
  final Map<String, dynamic>? createBody;
  final String? paymentId;
  final String? signature;

  bool get hasPaymentProof =>
      (paymentId ?? '').isNotEmpty && (signature ?? '').isNotEmpty;
}
