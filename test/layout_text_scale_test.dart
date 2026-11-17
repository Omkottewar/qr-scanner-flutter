import 'package:emergency_alert/presentation/home/home_tab.dart';
import 'package:emergency_alert/presentation/widgets/ea_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Renders key screens on a narrow phone at large system font sizes and
// fails on any RenderFlex overflow (the yellow/black stripe).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAt(WidgetTester tester, double scale, Widget child) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 760),
          textScaler: TextScaler.linear(scale),
        ),
        child: child,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('home tab has no overflow at ${scale}x text', (tester) async {
      await pumpAt(tester, scale,
          HomeTab(onOpenQr: () {}, onOpenDrawer: () {}));
      final overflow = tester.takeException();
      expect(overflow, isNull, reason: '$overflow');
    });

    testWidgets('primary button grows instead of clipping at ${scale}x', (tester) async {
      await pumpAt(tester, scale, Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: EaPrimaryButton(
              label: 'Pay ₹599 & Create QR',
              icon: Icons.lock_rounded,
              onPressed: () {},
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  }
}
