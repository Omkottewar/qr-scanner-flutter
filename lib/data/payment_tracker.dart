import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Fire-and-forget telemetry to POST /payments/track. Every Razorpay
/// SDK callback (success, failure, dismiss, external wallet) reports
/// through here so the backend logs — and therefore Render logs —
/// capture what actually happened on the user's device. Without this,
/// declined cards and network drops never touch our server and simply
/// vanish from our observability.
///
/// The endpoint is best-effort. If the report fails (e.g., the user
/// has no network) we log locally and move on — never block the UX on
/// a telemetry write.
abstract final class PaymentTracker {
  static Future<void> report({
    required String event,      // 'success' | 'failure' | 'dismiss' | 'external_wallet'
    String? orderId,
    String? code,
    String? description,
    String? source,             // 'qr_create' | 'qr_renew'
    Map<String, dynamic>? raw,
  }) async {
    try {
      final body = <String, dynamic>{
        'event': event,
        if (orderId != null && orderId.isNotEmpty) 'razorpay_order_id': orderId,
        if (code != null && code.isNotEmpty) 'code': code,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (source != null && source.isNotEmpty) 'source': source,
        if (raw != null && raw.isNotEmpty) 'raw': raw,
      };
      await ApiClient.instance.post('/payments/track', body);
      debugPrint('[track] $event order=${orderId ?? '(none)'} code=${code ?? '-'}');
    } catch (e) {
      // Never surface this — telemetry is a nicety.
      debugPrint('[track] report failed: $e');
    }
  }
}
