import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/ea_card.dart';

// Deep emergency red used across the printed sticker.
const Color _kEmergencyRed = Color(0xFFDC2626);
const Color _kInk = Color(0xFF111827);

class QrDetailCard extends StatefulWidget {
  const QrDetailCard({
    super.key,
    required this.alertUrl,
    required this.digits,
    required this.vehicleNumber,
    required this.ownerName,
    required this.bloodGroup,
    this.familyCount,
    this.isManual = false,
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  final String ownerName;
  final String bloodGroup;
  final int? familyCount; // shown as "N EMERGENCY BRANCHES"; hidden if null
  // Manual QRs are printed BEFORE the customer's vehicle is known, so
  // the physical sticker has no vehicle number on it. Reflecting that
  // in-app so what the customer sees matches what's on their windshield.
  final bool isManual;

  @override
  State<QrDetailCard> createState() => _QrDetailCardState();
}

class _QrDetailCardState extends State<QrDetailCard> {
  final GlobalKey _captureKey = GlobalKey();
  bool _saving = false;
  bool _sharing = false;

  Future<Uint8List?> _captureBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) throw Exception('Failed to render QR');
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) throw Exception('Photo library access denied');
      }
      await Gal.putImageBytes(bytes, name: 'qr-${widget.digits}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your gallery')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save QR: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) throw Exception('Failed to render QR');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr-${widget.digits}.png');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'My emergency QR — scan it to reach my family if you find me in trouble.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share QR: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // FittedBox uniformly scales the fixed-width sticker design
          // down to whatever horizontal space the parent card gives us,
          // so text like "QR 4 EMERGENCY" and "BE NAYAK" never wraps.
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: _captureKey,
                child: _StickerSurface(
                  alertUrl: widget.alertUrl,
                  digits: widget.digits,
                  vehicleNumber: widget.vehicleNumber,
                  familyCount: widget.familyCount,
                  isManual: widget.isManual,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.ownerName.isNotEmpty) Text('Name: ${widget.ownerName}'),
          if (widget.bloodGroup.isNotEmpty)
            Text('Blood Group: ${widget.bloodGroup}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _download,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(_saving ? 'Saving…' : 'Download'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined),
                  label: Text(_sharing ? 'Sharing…' : 'Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Print-ready windshield sticker. Layout mirrors the physical vinyl
/// design 1:1 so what the customer sees in-app matches what they'll
/// stick on their vehicle. Rasterised on tap of Download / Share.
///
/// Structure (top to bottom):
///   1. Red header    — QR 4 EMERGENCY + SCAN TO CALL OWNER
///   2. White body    — vehicle number in red (skipped when isManual),
///                      corner-bracketed QR flanked by red medical
///                      crosses, extension number pill, BE NAYAK
///   3. Black footer  — website + support email row, then
///                      ACCIDENT / TRACKING / NO PARKING badges
class _StickerSurface extends StatelessWidget {
  const _StickerSurface({
    required this.alertUrl,
    required this.digits,
    required this.vehicleNumber,
    required this.familyCount,
    required this.isManual,
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  // ignore: unused_element_parameter
  final int? familyCount;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    // Manual QRs are printed before the vehicle is known — the physical
    // sticker literally has no vehicle number on it. Only show the
    // vehicle line if this is an auto (paid-during-app) QR AND the
    // caller passed a value.
    final showVehicle = !isManual && vehicleNumber.trim().isNotEmpty;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Red header band ─────────────────────────────────
            Container(
              width: double.infinity,
              color: _kEmergencyRed,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'QR 4 EMERGENCY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'SCAN TO CALL OWNER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            // ── White body ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row: [cross] [ bracketed frame: vehicle + QR ] [cross]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _MedicalCross(size: 44),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _CornerBracketFrame(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showVehicle) ...[
                                  Text(
                                    vehicleNumber.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _kEmergencyRed,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.4,
                                      height: 1.0,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                QrImageView(
                                  data: alertUrl,
                                  version: QrVersions.auto,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: _kInk,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: _kInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const _MedicalCross(size: 44),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Extension Number',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kEmergencyRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      digits.isNotEmpty ? digits : '—',
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        height: 1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'BE NAYAK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kInk,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            // ── Black footer ────────────────────────────────────
            Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Web + email row separated by green dot · pipe · green dot.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Icon(Icons.language_rounded,
                          size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'www.qr4emergency.com',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      _FooterDot(color: Color(0xFF22C55E)),
                      SizedBox(width: 5),
                      _FooterPipe(),
                      SizedBox(width: 5),
                      _FooterDot(color: Color(0xFF22C55E)),
                      SizedBox(width: 6),
                      Icon(Icons.mail_outline_rounded,
                          size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'support@qr4emergency.com',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Three feature badges, matching the printed sticker.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _FooterBadge(
                        icon: Icons.warning_amber_rounded,
                        iconColor: _kEmergencyRed,
                        label: 'ACCIDENT',
                      ),
                      _FooterDivider(),
                      _FooterBadge(
                        icon: Icons.location_on_rounded,
                        iconColor: Color(0xFF22C55E),
                        label: 'TRACKING',
                      ),
                      _FooterDivider(),
                      _FooterBadge(
                        icon: Icons.do_not_disturb_on_outlined,
                        iconColor: _kEmergencyRed,
                        label: 'NO PARKING',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner-bracket frame wrapping the vehicle number + QR block —
/// four L-shaped marks at the outer corners, no full border. Matches
/// the scanner-target look on the printed sticker.
class _CornerBracketFrame extends StatelessWidget {
  const _CornerBracketFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _BracketPainter()),
          ),
        ),
      ],
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kInk
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    // Bracket arm length as a fraction of the frame size.
    final arm = size.width * 0.14;
    final w = size.width;
    final h = size.height;
    // Top-left
    canvas.drawLine(const Offset(0, 0), Offset(arm, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, arm), paint);
    // Top-right
    canvas.drawLine(Offset(w - arm, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, arm), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - arm), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(arm, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - arm, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - arm), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Red medical/emergency cross used as decoration on either side of
/// the QR code. Two overlapping rectangles form the plus symbol.
class _MedicalCross extends StatelessWidget {
  const _MedicalCross({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final barThickness = size * 0.35;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: barThickness,
            height: size,
            color: _kEmergencyRed,
          ),
          Container(
            width: size,
            height: barThickness,
            color: _kEmergencyRed,
          ),
        ],
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  const _FooterDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FooterPipe extends StatelessWidget {
  const _FooterPipe();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      color: Colors.white.withValues(alpha: 0.6),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

class _FooterBadge extends StatelessWidget {
  const _FooterBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
