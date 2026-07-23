import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/payment_tracker.dart';
import '../../data/pending_order_store.dart';
import '../widgets/ea_primary_button.dart';

// Modal bottom sheet that walks the user through a one-tap renewal.
// Flow:
//   1. initState → POST /qr/:id/renew/order → gets Razorpay orderId+amount+key.
//   2. User taps "Pay ₹99" → open Razorpay checkout.
//   3. On checkout success → POST /qr/:id/renew/verify with the signature.
//      Backend extends date_of_activation by 1 year and flips is_active on.
//   4. Sheet closes with `true`, parent refreshes History.
//
// Any failure closes the sheet with `false` and surfaces the error via a
// SnackBar in the parent — the sheet itself just reports state via a
// return value so the caller controls the recovery UX.
class RenewSheet extends StatefulWidget {
  const RenewSheet({
    super.key,
    required this.qrId,
    required this.vehicleNumber,
    required this.userMobile,
  });

  final int qrId;
  final String vehicleNumber;
  final String userMobile;

  @override
  State<RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<RenewSheet> {
  Razorpay? _rz;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  String? _orderId;
  String? _keyId;
  int? _amountPaise;         // what Razorpay will actually charge
  int? _intendedAmountPaise; // what to display to the user

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  @override
  void dispose() {
    _rz?.clear();
    super.dispose();
  }

  // Blocks double-fire of Razorpay success callback. Without it, retries
  // in the SDK would trigger a duplicate /renew/verify — and a duplicate
  // Navigator.pop on an already-closed sheet.
  bool _verifying = false;

  Future<void> _createOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance
          .post('/qr/${widget.qrId}/renew/order', const <String, dynamic>{});
      if (!mounted) return;
      if (res is! Map) throw Exception('Invalid response');
      final orderId = res['order_id']?.toString();
      setState(() {
        _orderId = orderId;
        _keyId = res['key_id']?.toString();
        _amountPaise = (res['amount'] as num?)?.toInt();
        // Fallback to `amount` when the server hasn't shipped the new
        // field yet.
        _intendedAmountPaise = (res['intended_amount'] as num?)?.toInt()
            ?? _amountPaise;
      });
      // Persist so an OS kill mid-checkout is recoverable on relaunch.
      if (orderId != null && orderId.isNotEmpty) {
        await PendingOrderStore.save(
          orderId: orderId,
          purpose: 'qr_renew',
          qrId: widget.qrId,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyAndClose({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    if (_verifying) return;
    _verifying = true;
    if (mounted) setState(() => _paying = true);
    try {
      await ApiClient.instance
          .post('/qr/${widget.qrId}/renew/verify', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      // Renewal succeeded — clear the pending marker so the boot
      // recovery flow doesn't ask about it again.
      await PendingOrderStore.clear();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      // Renewal verify failed AFTER Razorpay confirmed payment. Before
      // showing a scary error, check the payments audit — a lost
      // response (network drop between UPDATE and reply) can look like
      // failure but the server actually renewed the QR. If we spot the
      // verified row we close successfully.
      debugPrint('[renew/verify] failed after razorpay success: $e');
      final recovered = await _tryRecoverFromPaymentStatus(orderId);
      if (recovered) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }
      _verifying = false; // allow a retry after a verify failure
      if (mounted) {
        setState(() {
          _error = 'Payment succeeded but we couldn\'t activate your renewal. Tap Retry, or contact support with order ID $orderId if it still fails. (${ErrorMessages.friendly(e)})';
          _paying = false;
        });
      }
    }
  }

  // Same recovery pattern as payment_screen: if /renew/verify blew up
  // but /payments/status/:orderId says the payment was verified, the
  // renewal actually landed. Returns true if the audit confirms it —
  // caller closes the sheet successfully.
  Future<bool> _tryRecoverFromPaymentStatus(String orderId) async {
    if (orderId.isEmpty) return false;
    try {
      final res = await ApiClient.instance.get('/payments/status/$orderId');
      if (res is! Map || res['found'] != true) return false;
      if (res['status']?.toString() != 'verified') return false;
      await PendingOrderStore.clear();
      debugPrint('[renew/verify] recovered via /payments/status');
      return true;
    } catch (e) {
      debugPrint('[renew/verify] recovery attempt failed: $e');
      return false;
    }
  }

  void _onSuccess(PaymentSuccessResponse r) {
    // Fire before /renew/verify so a subsequent server-side failure
    // still leaves a "customer paid" trace in Render logs.
    PaymentTracker.report(
      event: 'success',
      orderId: r.orderId ?? _orderId,
      source: 'qr_renew',
      raw: {
        'payment_id': r.paymentId,
        'signature_present': (r.signature ?? '').isNotEmpty,
        'qr_id': widget.qrId,
      },
    );
    _verifyAndClose(
      orderId: r.orderId ?? _orderId ?? '',
      paymentId: r.paymentId ?? '',
      signature: r.signature ?? '',
    );
  }

  void _onError(PaymentFailureResponse r) {
    if (!mounted) return;
    // Razorpay conflates "payment failed" with "user dismissed the
    // modal". Show honest copy for the cancellation path so the user
    // doesn't think their card was declined.
    final raw = (r.message ?? '').toLowerCase();
    final isDismiss = raw.contains('cancel') || raw.contains('dismiss');
    // Ship the failure detail to the backend so it appears in Render
    // logs — Razorpay's own modal-side errors otherwise never touch us.
    PaymentTracker.report(
      event: isDismiss ? 'dismiss' : 'failure',
      orderId: _orderId,
      code: r.code?.toString(),
      description: r.message,
      source: 'qr_renew',
      raw: {
        if (r.error != null) 'error': r.error.toString(),
        'qr_id': widget.qrId,
      },
    );
    setState(() {
      _paying = false;
      _error = isDismiss
          ? 'Payment cancelled — you can try again anytime.'
          : (r.message ?? 'Payment failed').trim();
    });
  }

  void _openCheckout() {
    if (_orderId == null || _keyId == null || _amountPaise == null) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    _rz ??= Razorpay();
    _rz!
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _rz!.open({
      'key': _keyId,
      'amount': _amountPaise,
      'currency': 'INR',
      'name': 'QR 4 Emergency',
      'description': 'Renew ${widget.vehicleNumber}',
      'order_id': _orderId,
      'prefill': {'contact': widget.userMobile},
    });
  }

  @override
  Widget build(BuildContext context) {
    // Renewal price (₹99 default).
    final displayPaise = _intendedAmountPaise ?? _amountPaise ?? 9900;
    final rupees = (displayPaise / 100).toStringAsFixed(0);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.autorenew_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Renew this QR',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.vehicleNumber,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extends your QR by 1 year from today (or from current expiry, whichever is later).',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹$rupees',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ year',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              EaPrimaryButton(
                label: _paying ? 'Please wait…' : 'Pay ₹$rupees',
                icon: Icons.lock_rounded,
                loading: _paying,
                onPressed: (_paying || _orderId == null) ? null : _openCheckout,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _paying ? null : () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
