import 'package:emergency_alert/data/pending_order_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves the QR form so a paid order can be finished after restart', () async {
    await PendingOrderStore.save(
      orderId: 'order_1',
      purpose: 'qr_create',
      createBody: {'name': 'Asha', 'vehicle_number': 'MH12AB1234', 'family': []},
    );
    final p = await PendingOrderStore.read();
    expect(p, isNotNull);
    expect(p!.createBody?['vehicle_number'], 'MH12AB1234');
    expect(p.hasPaymentProof, isFalse);
  });

  test('stores payment proof only for the current order', () async {
    await PendingOrderStore.save(orderId: 'order_1', purpose: 'qr_create');
    await PendingOrderStore.savePaymentProof(
        orderId: 'order_other', paymentId: 'pay_x', signature: 'sig_x');
    expect((await PendingOrderStore.read())!.hasPaymentProof, isFalse);

    await PendingOrderStore.savePaymentProof(
        orderId: 'order_1', paymentId: 'pay_1', signature: 'sig_1');
    final p = (await PendingOrderStore.read())!;
    expect(p.hasPaymentProof, isTrue);
    expect(p.paymentId, 'pay_1');
  });

  test('a new order replaces the old proof', () async {
    await PendingOrderStore.save(orderId: 'order_1', purpose: 'qr_create');
    await PendingOrderStore.savePaymentProof(
        orderId: 'order_1', paymentId: 'pay_1', signature: 'sig_1');
    await PendingOrderStore.save(orderId: 'order_2', purpose: 'qr_renew', qrId: 5);
    final p = (await PendingOrderStore.read())!;
    expect(p.orderId, 'order_2');
    expect(p.qrId, 5);
    expect(p.hasPaymentProof, isFalse);
    expect(p.createBody, isNull);
  });

  test('unpaid orders expire after a day, paid ones are kept for a week', () async {
    final twoDaysAgo =
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'pending_order_id': 'order_old',
      'pending_order_purpose': 'qr_create',
      'pending_order_created_at': twoDaysAgo,
    });
    expect(await PendingOrderStore.read(), isNull);

    SharedPreferences.setMockInitialValues({
      'pending_order_id': 'order_paid',
      'pending_order_purpose': 'qr_create',
      'pending_order_created_at': twoDaysAgo,
      'pending_order_payment_id': 'pay_1',
      'pending_order_signature': 'sig_1',
    });
    expect((await PendingOrderStore.read())?.orderId, 'order_paid');
  });

  test('clear removes everything', () async {
    await PendingOrderStore.save(
        orderId: 'order_1', purpose: 'qr_create', createBody: {'a': 1});
    await PendingOrderStore.clear();
    expect(await PendingOrderStore.read(), isNull);
  });
}
