import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/payment_tracker.dart';
import '../../data/pending_order_store.dart';
import '../../models/create_qr_draft.dart';
import '../widgets/ea_card.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/ea_text_field.dart';
import 'qr_flow_tab.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onSuccess,
  });

  final CreateQrDraft draft;
  final VoidCallback onBack;
  final void Function(QrCreateResult result) onSuccess;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Razorpay? _rz;
  String _method = 'upi';
  final _upiId = TextEditingController();
  bool _loading = false;
  String? _orderId;
  String? _keyId;
  int? _amountPaise;         // what Razorpay will actually charge
  int? _intendedAmountPaise; // what the UI shows (real subscription price)
  bool _demoMode = false;

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  @override
  void dispose() {
    _upiId.dispose();
    _rz?.clear();
    super.dispose();
  }

  // Guards against Razorpay firing the success listener more than once
  // (retry logic in their SDK) — the second invocation would trigger a
  // duplicate /qr/create call and a duplicate onSuccess navigation.
  bool _completing = false;

  Future<void> _createOrder() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.post('/payments/razorpay/order', {
        'vehicle_number': widget.draft.vehicleNumber,
      });
      if (!mounted) return;
      if (res is! Map) {
        throw Exception('Unexpected server response for order');
      }
      final map = Map<String, dynamic>.from(res);
      final orderId = map['order_id'] as String?;
      setState(() {
        _orderId = orderId;
        _keyId = map['key_id'] as String?;
        _amountPaise = (map['amount'] as num?)?.toInt();
        // Fallback to `amount` when the server hasn't shipped the new
        // field yet — keeps the UI honest against both response shapes.
        _intendedAmountPaise = (map['intended_amount'] as num?)?.toInt()
            ?? _amountPaise;
        _demoMode = map['demo_mode'] == true;
      });
      // Persist the order id NOW so an OS kill mid-checkout can be
      // recovered on next launch instead of double-charging the user.
      if (orderId != null && orderId.isNotEmpty) {
        await PendingOrderStore.save(
          orderId: orderId,
          purpose: 'qr_create',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeCreate ({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    // Ignore duplicate success events — see _completing docstring.
    if (_completing) return;
    _completing = true;
    setState(() => _loading = true);
    try {
      final body = {
        ...widget.draft.toPaymentJson(),
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      };
      final res = await ApiClient.instance.post('/qr/create', body);
      if (!mounted) return;
      if (res is! Map) {
        throw Exception('Unexpected server response');
      }
      final map = Map<String, dynamic>.from(res);
      final uniqueId = map['unique_id']?.toString();
      final alertUrl = map['alert_url']?.toString();
      final vehicleNumber = map['vehicle_number']?.toString();
      if (uniqueId == null || alertUrl == null || vehicleNumber == null) {
        throw Exception('Server response missing required fields');
      }
      // Order is complete — clear the pending marker so it doesn't
      // trigger a spurious "resume payment" prompt on next launch.
      await PendingOrderStore.clear();
      widget.onSuccess(
        QrCreateResult(
          uniqueId: uniqueId,
          digits: map['digits']?.toString() ?? '',
          alertUrl: alertUrl,
          vehicleNumber: vehicleNumber,
          ownerName: widget.draft.name,
          bloodGroup: widget.draft.bloodGroup,
          familyCount: widget.draft.family.length,
        ),
      );
    } catch (e) {
      // /qr/create failed AFTER Razorpay confirmed payment. The card
      // was charged — the user MUST not be left in limbo. Ask the
      // backend if the payment audit says the QR was actually created
      // (response might have been lost in transit or a prior attempt
      // may have succeeded server-side). If yes, recover by fetching
      // the QR from history and moving to the success screen.
      debugPrint('[qr/create] [CRITICAL] payment succeeded but QR creation failed '
          'order=$orderId payment=$paymentId error=$e');
      // Fire a telemetry event so this "money taken, QR not created"
      // condition shows up in Render logs alongside every other Razorpay
      // event. Use a distinctive event name for easy grep-based alerting.
      PaymentTracker.report(
        event: 'qr_creation_failed_after_payment',
        orderId: orderId,
        description: 'Payment succeeded (paymentId=$paymentId) but /qr/create '
            'failed. First recovery attempt will now query /payments/status.',
        source: 'qr_create',
        raw: {
          'error': e.toString(),
          'payment_id': paymentId,
          'signature_present': signature.isNotEmpty,
        },
      );
      final recovered = await _tryRecoverFromPaymentStatus(orderId);
      if (recovered) return;
      // Recovery failed too — this is the truly-stuck state. Emit a
      // second, louder telemetry line so it's obvious in dashboards
      // that a human needs to reconcile this order manually.
      debugPrint('[qr/create] [CRITICAL] recovery via /payments/status also '
          'failed order=$orderId — manual reconciliation required');
      PaymentTracker.report(
        event: 'qr_creation_stuck',
        orderId: orderId,
        description: 'Payment verified server-side but QR still not created '
            'after recovery poll. Manual reconciliation required.',
        source: 'qr_create',
        raw: {
          'error': e.toString(),
          'payment_id': paymentId,
        },
      );
      _completing = false; // real failure — let the user retry
      if (!mounted) return;
      // Post-payment failures deserve a proper dialog with recovery
      // affordances, not a fleeting SnackBar.
      _showPostPaymentFailureDialog(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        error: e,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Looks up /payments/status/:orderId. If the backend says the payment
  // was verified and linked to a QR, we can still navigate the user
  // forward — the transaction happened, only the response transport
  // failed. Returns true if recovery succeeded (caller should stop).
  Future<bool> _tryRecoverFromPaymentStatus(String orderId) async {
    if (orderId.isEmpty) return false;
    try {
      final res = await ApiClient.instance.get('/payments/status/$orderId');
      if (res is! Map || res['found'] != true) return false;
      final status = res['status']?.toString();
      if (status != 'verified') return false;
      final qrIdRaw = res['qr_id'];
      if (qrIdRaw == null) return false;
      // Fetch the QR from history to build a proper QrCreateResult.
      final hist = await ApiClient.instance.get('/qr/history');
      if (hist is! Map) return false;
      final items = (hist['items'] as List?) ?? const [];
      final match = items.whereType<Map>().firstWhere(
        (r) => r['id'] == qrIdRaw,
        orElse: () => const {},
      );
      if (match.isEmpty) return false;
      if (!mounted) return true; // still counts as recovered
      debugPrint('[qr/create] recovered via /payments/status → qr_id=$qrIdRaw');
      await PendingOrderStore.clear();
      widget.onSuccess(
        QrCreateResult(
          uniqueId: match['unique_id']?.toString() ?? '',
          digits: match['digits']?.toString() ?? '',
          alertUrl: match['alert_url']?.toString() ?? '',
          vehicleNumber: match['vehicle_number']?.toString() ?? '',
          ownerName: widget.draft.name,
          bloodGroup: widget.draft.bloodGroup,
          familyCount: widget.draft.family.length,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[qr/create] recovery attempt failed: $e');
      return false;
    }
  }

  // Full-screen-blocking dialog for the rare "we charged you but
  // couldn't create your QR" state. Gives the user three concrete
  // actions instead of a fleeting SnackBar they can miss. Retry needs
  // the original Razorpay credentials so the backend can either
  // idempotently return the existing QR (if a prior attempt secretly
  // succeeded) or run signature verification again.
  void _showPostPaymentFailureDialog({
    required String orderId,
    required String paymentId,
    required String signature,
    required Object error,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: AppColors.amber, size: 30),
        ),
        title: const Text('We couldn\'t create your QR', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ErrorMessages.friendly(error),
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment is safe. If your card was charged, please share this reference with support and we\'ll either finish creating your QR or issue a refund:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              orderId,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onBack(); // back to the form so they can retry
            },
            child: const Text('Back to form'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Retry with the ORIGINAL credentials. If a prior attempt
              // silently succeeded server-side, the idempotency lookup
              // returns the existing QR without re-verifying. Otherwise
              // signature verification runs again — same creds, same
              // result, so this only helps for transient failures like
              // a DB blip on the first attempt.
              await _completeCreate(
                orderId: orderId,
                paymentId: paymentId,
                signature: signature,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRazorpaySuccess(PaymentSuccessResponse r) async {
    // Razorpay's SDK invokes this from a native thread — any unhandled
    // exception here silently disappears and the user is left staring
    // at a spinner or a stale screen after paying. Wrap the entire body
    // so every failure path gets logged and telemetered.
    final orderId = r.orderId ?? _orderId ?? '';
    final paymentId = r.paymentId ?? '';
    final signature = r.signature ?? '';
    try {
      // Server-side visibility for the "SDK said yes" moment. Fire before
      // /qr/create so even a subsequent /qr/create failure leaves a trace
      // in Render logs proving the customer's card WAS charged.
      debugPrint('[razorpay/success] order=$orderId payment=$paymentId '
          'signature_present=${signature.isNotEmpty}');
      PaymentTracker.report(
        event: 'success',
        orderId: orderId.isEmpty ? null : orderId,
        source: 'qr_create',
        raw: {
          'payment_id': paymentId,
          'signature_present': signature.isNotEmpty,
        },
      );
      await _completeCreate(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
    } catch (e, st) {
      // If we reach here, something outside _completeCreate's own
      // try/catch threw — likely a bug in our own success handler.
      // Log loudly so it doesn't fall on the floor.
      debugPrint('[razorpay/success] [CRITICAL] unhandled exception in '
          '_onRazorpaySuccess order=$orderId payment=$paymentId error=$e\n$st');
      PaymentTracker.report(
        event: 'success_handler_crashed',
        orderId: orderId.isEmpty ? null : orderId,
        source: 'qr_create',
        description: 'Unhandled exception inside _onRazorpaySuccess after '
            'Razorpay confirmed payment. Manual reconciliation required.',
        raw: {
          'error': e.toString(),
          'payment_id': paymentId,
          'stack': st.toString().split('\n').take(6).join(' | '),
        },
      );
      if (!mounted) return;
      _completing = false;
      setState(() => _loading = false);
      _showPostPaymentFailureDialog(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        error: e,
      );
    }
  }

  void _onRazorpayError(PaymentFailureResponse r) {
    if (!mounted) return;
    try {
      // Razorpay SDK fires this for both "payment failed" AND "user
      // dismissed the modal" (code=2 / BAD_REQUEST_ERROR with a
      // "cancelled" message). Distinguish the two so the copy is honest.
      final rawMsg = (r.message ?? '').toLowerCase();
      final isDismiss = rawMsg.contains('cancel') || rawMsg.contains('dismiss');
      debugPrint('[razorpay/error] order=${_orderId ?? '(none)'} '
          'code=${r.code} message=${r.message} isDismiss=$isDismiss');
      // Report to backend so Render logs capture the failure. This is
      // the one class of failure that otherwise NEVER touches our
      // server — without this line, declined cards and network drops
      // during the Razorpay modal are completely invisible in prod.
      PaymentTracker.report(
        event: isDismiss ? 'dismiss' : 'failure',
        orderId: _orderId,
        code: r.code?.toString(),
        description: r.message,
        source: 'qr_create',
        raw: {
          if (r.error != null) 'error': r.error.toString(),
        },
      );

      // Modal dismissal is unambiguous — the user hit the X. No
      // recovery possible; go straight to a friendly toast.
      if (isDismiss) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment cancelled — you can try again anytime.')),
        );
        return;
      }

      // NOT a dismiss — could be UPI Collect timeout while NPCI is still
      // processing. Race Razorpay's webhook: poll /payments/status for a
      // few seconds. If webhook confirms payment.captured, continue the
      // QR-creation flow using the server-derived payment_id (no client
      // signature — server trusts its own HMAC-verified webhook row).
      _reconcileAfterClientError(r);
    } catch (e, st) {
      debugPrint('[razorpay/error] [CRITICAL] unhandled exception in '
          '_onRazorpayError order=${_orderId ?? '(none)'} error=$e\n$st');
      PaymentTracker.report(
        event: 'error_handler_crashed',
        orderId: _orderId,
        source: 'qr_create',
        description: 'Unhandled exception inside _onRazorpayError',
        raw: {
          'error': e.toString(),
          'stack': st.toString().split('\n').take(6).join(' | '),
        },
      );
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessages.friendly(e))),
      );
    }
  }

  // Polls /payments/status/:orderId briefly after a Razorpay client-side
  // failure. If the payment turns out to be verified server-side within
  // the window, we complete /qr/create and take the user to success.
  // Otherwise we fall through to the standard failure dialog.
  Future<void> _reconcileAfterClientError(PaymentFailureResponse r) async {
    final orderId = _orderId ?? '';
    if (orderId.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyRazorpayFailure(r))),
      );
      return;
    }

    // Give the webhook up to ~12s to arrive. UPI captures usually land
    // within 2–5s after the client-side timeout fires; 12s is generous.
    setState(() => _loading = true);
    const attempts = 6;
    const delayMs = 2000;
    String? verifiedPaymentId;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: delayMs));
      if (!mounted) return;
      try {
        final res = await ApiClient.instance.get('/payments/status/$orderId');
        if (res is Map && res['found'] == true) {
          final status = res['status']?.toString();
          if (status == 'verified') {
            verifiedPaymentId = res['razorpay_payment_id']?.toString();
            break;
          }
          if (status == 'failed') break; // real failure, stop polling
        }
      } catch (e) {
        debugPrint('[payment] reconcile poll error: $e');
      }
    }

    if (!mounted) return;

    if (verifiedPaymentId != null && verifiedPaymentId.isNotEmpty) {
      // Webhook confirmed the payment. Continue as if success — the
      // server will trust its own webhook row and skip signature check.
      debugPrint('[payment] webhook confirmed after client error → completing QR');
      await _completeCreate(
        orderId: orderId,
        paymentId: verifiedPaymentId,
        signature: '', // empty — server trusts the webhook-verified row
      );
      return;
    }

    // Genuine failure — surface the friendly copy. Marker stays so the
    // next launch can double-check.
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyRazorpayFailure(r))),
    );
  }

  // Razorpay SDK's EVENT_EXTERNAL_WALLET fires for the "pay with a
  // wallet app" path; we don't handle those specially, but need the
  // listener attached so the SDK doesn't warn about unhandled events.
  void _onExternalWallet(ExternalWalletResponse r) {
    try {
      debugPrint('[razorpay/external-wallet] wallet=${r.walletName} '
          'order=${_orderId ?? '(none)'}');
      PaymentTracker.report(
        event: 'external_wallet',
        orderId: _orderId,
        description: r.walletName,
        source: 'qr_create',
      );
    } catch (e, st) {
      debugPrint('[razorpay/external-wallet] [CRITICAL] unhandled exception '
          'wallet=${r.walletName} error=$e\n$st');
    }
  }

  // Turn a raw Razorpay PaymentFailureResponse into human copy. Their
  // `code` is an int enum and `message` is often a terse
  // "GATEWAY_ERROR" style token — neither is user-friendly on its own.
  String _friendlyRazorpayFailure(PaymentFailureResponse r) {
    final raw = (r.message ?? '').toLowerCase();
    // Razorpay's most common UPI failure: "Payment was unsuccessful as
    // the payment could not be completed in time by the customer." The
    // customer's UPI app often shows "PIN accepted" seconds before
    // this, so they think the payment succeeded and are surprised by
    // the failure. Give them the truth so they don't retry blindly
    // and end up paying twice — Razorpay auto-refunds any deduction.
    if (raw.contains('could not be completed in time') ||
        raw.contains('payment timed out') ||
        raw.contains('customer timed out')) {
      return "Your UPI payment took too long to confirm and was cancelled by the network. If your bank showed a debit, Razorpay will refund it automatically within 5-7 working days — no action needed. Try again with a stable network for the fastest experience.";
    }
    if (raw.contains('insufficient')) {
      return 'Payment declined — insufficient balance in your account.';
    }
    if (raw.contains('network') && !raw.contains('gateway')) {
      return 'Payment failed due to a network issue. Please try again on a stable connection.';
    }
    if (raw.contains('gateway') && raw.contains('technical')) {
      return "Payment gateway had a technical issue. Please try again in a moment.";
    }
    if (raw.contains('gateway') || raw.contains('bank')) {
      return "Your bank declined the payment. Try a different card, UPI account, or payment method.";
    }
    if (raw.contains('invalid')) {
      return 'Payment declined — please check your details and try again.';
    }
    if (raw.contains('cancel') || raw.contains('dismiss')) {
      return 'Payment cancelled — you can try again anytime.';
    }
    if (raw.isEmpty) return 'Payment failed. Please try again.';
    return 'Payment failed: ${r.message}';
  }

  void _openCheckout() {
    try {
      if (_demoMode) {
        _completeCreate(
          orderId: _orderId ?? 'order_dev',
          paymentId: 'pay_dev_${DateTime.now().millisecondsSinceEpoch}',
          signature: 'dev_sig',
        );
        return;
      }
      if (_orderId == null || _keyId == null || _amountPaise == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not ready')),
        );
        return;
      }
      _rz ??= Razorpay();
      _rz!
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

      final options = {
        'key': _keyId,
        'amount': _amountPaise,
        'currency': 'INR',
        'name': 'Emergency Alert',
        'description': 'QR 4 Emergency — Lifetime (one-time)',
        'order_id': _orderId,
        'prefill': {
          'contact': widget.draft.mobile,
          'email': widget.draft.email,
        },
      };
      debugPrint('[razorpay/open] order=$_orderId amount=$_amountPaise '
          'key=${_keyId?.substring(0, 8)}...');
      _rz!.open(options);
    } catch (e, st) {
      // Rare, but possible: Razorpay SDK can throw synchronously if the
      // options are malformed or the plugin isn't initialised. Without
      // this catch the user sees a frozen UI with no explanation.
      debugPrint('[razorpay/open] [CRITICAL] failed to open checkout '
          'order=${_orderId ?? '(none)'} error=$e\n$st');
      PaymentTracker.report(
        event: 'checkout_open_failed',
        orderId: _orderId,
        source: 'qr_create',
        description: 'Razorpay SDK threw when opening the checkout modal.',
        raw: {
          'error': e.toString(),
          'stack': st.toString().split('\n').take(6).join(' | '),
        },
      );
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessages.friendly(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display uses the intended (real) price so subscribers always see
    // ₹299 on the button. The actual charge (_amountPaise) is what
    // Razorpay's modal will show and debit.
    final displayPaise = _intendedAmountPaise ?? _amountPaise ?? 29900;
    final rupees = (displayPaise / 100).toStringAsFixed(0);
    final actualCharge = _amountPaise ?? displayPaise;
    final isTestOverride = _amountPaise != null &&
        _intendedAmountPaise != null &&
        actualCharge != displayPaise;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('Payment'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EaCard(
                    border: Border.all(color: AppColors.primary),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR 4 Emergency — Lifetime',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'One-time payment · No renewal',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        // Line-item breakdown so the customer sees exactly
                        // what they're paying for. Numbers match the
                        // config.pricing values on the backend and the
                        // invoice email they'll receive after checkout.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Platform fee',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                            const Text(
                              '₹499',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Shipping',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                            const Text(
                              '₹50',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, thickness: 0.5),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Total',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Text(
                              '₹$rupees',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                        // Test-charge disclosure — only appears when the
                        // backend's TEST_CHARGE_AMOUNT_PAISE override is
                        // active and the actual charge differs from the
                        // displayed subscription price.
                        if (isTestOverride) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.amber.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.science_outlined,
                                    color: AppColors.amber, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Test mode — Razorpay will only charge '
                                    '₹${(actualCharge / 100).toStringAsFixed(2)} '
                                    'for this transaction.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.stepGreen, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Includes:',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...[
                                'Generate QR Codes',
                                'Up to 5 Emergency Contacts',
                                'Call Masking Feature',
                                'Waterproof QR Sticker',
                                'Lifetime access · No annual renewal',
                              ].map((t) => Text('• $t', style: Theme.of(context).textTheme.bodySmall)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  EaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Powered by Razorpay',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _PayOption(
                          selected: _method == 'upi',
                          title: 'UPI',
                          subtitle: 'Pay using any UPI app.',
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF7C3AED),
                          onTap: () => setState(() => _method = 'upi'),
                        ),
                        _PayOption(
                          selected: _method == 'card',
                          title: 'Credit/Debit Card',
                          subtitle: 'Visa, Mastercard, RuPay.',
                          icon: Icons.credit_card,
                          iconColor: const Color(0xFF2563EB),
                          onTap: () => setState(() => _method = 'card'),
                        ),
                        _PayOption(
                          selected: _method == 'netbanking',
                          title: 'Net Banking',
                          subtitle: 'All major banks supported.',
                          icon: Icons.account_balance_outlined,
                          iconColor: const Color(0xFF16A34A),
                          onTap: () => setState(() => _method = 'netbanking'),
                        ),
                        if (_method == 'upi') ...[
                          const SizedBox(height: 12),
                          EaTextField(
                            controller: _upiId,
                            label: 'UPI ID',
                            hint: 'example@upi',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: EaPrimaryButton(
              label: _loading
                  ? 'Please wait…'
                  : _demoMode
                      ? 'Simulate payment (dev)'
                      : 'Pay ₹$rupees',
              onPressed: _loading ? null : _openCheckout,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? AppColors.primary : Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
