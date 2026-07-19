import 'package:flutter/material.dart';

import '../../models/create_qr_draft.dart';
import 'create_qr_form_screen.dart';
import 'create_qr_intro_screen.dart';
import 'payment_screen.dart';
import 'qr_success_screen.dart';

enum _QrStage { intro, form, payment, success }

class QrFlowTab extends StatefulWidget {
  const QrFlowTab({
    super.key,
    this.onInnerChanged,
    this.onRequestHome,
  });

  final ValueChanged<bool>? onInnerChanged;
  final VoidCallback? onRequestHome;

  @override
  State<QrFlowTab> createState() => QrFlowTabState();
}

class QrFlowTabState extends State<QrFlowTab> {
  _QrStage _stage = _QrStage.intro;
  CreateQrDraft? _draft;
  QrCreateResult? _result;

  bool get isInner => _stage != _QrStage.intro;

  void _setStage(_QrStage s) {
    widget.onInnerChanged?.call(s != _QrStage.intro);
    setState(() => _stage = s);
  }

  void resetToIntro() {
    widget.onInnerChanged?.call(false);
    setState(() {
      _stage = _QrStage.intro;
      _draft = null;
      _result = null;
    });
  }

  void _goHomeAndReset() {
    resetToIntro();
    widget.onRequestHome?.call();
  }

  /// Called by the host shell when the system back button is pressed.
  /// Returns true if the QR flow consumed the back press.
  bool stepBack() {
    switch (_stage) {
      case _QrStage.intro:
        return false;
      case _QrStage.form:
        _setStage(_QrStage.intro);
        return true;
      case _QrStage.payment:
        _setStage(_QrStage.form);
        return true;
      case _QrStage.success:
        _goHomeAndReset();
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _QrStage.intro:
        return CreateQrIntroScreen(
          onStart: () => _setStage(_QrStage.form),
        );
      case _QrStage.form:
        return CreateQrFormScreen(
          onBack: resetToIntro,
          onProceedToPayment: (d) {
            _draft = d;
            _setStage(_QrStage.payment);
          },
          onCreatedDirectly: (r) {
            _result = r;
            _setStage(_QrStage.success);
          },
        );
      case _QrStage.payment:
        return PaymentScreen(
          draft: _draft!,
          onBack: () => _setStage(_QrStage.form),
          onSuccess: (r) {
            _result = r;
            _setStage(_QrStage.success);
          },
        );
      case _QrStage.success:
        return QrSuccessScreen(
          result: _result!,
          onGoHome: _goHomeAndReset,
        );
    }
  }
}

class QrCreateResult {
  QrCreateResult({
    required this.uniqueId,
    required this.digits,
    required this.alertUrl,
    required this.vehicleNumber,
    required this.ownerName,
    required this.bloodGroup,
    this.familyCount,
  });

  final String uniqueId;
  final String digits;
  final String alertUrl;
  final String vehicleNumber;
  final String ownerName;
  final String bloodGroup;
  final int? familyCount;
}
