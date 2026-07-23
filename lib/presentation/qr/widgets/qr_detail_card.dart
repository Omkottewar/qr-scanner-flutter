import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/ea_card.dart';

// Brand fonts kept in sync with backend/src/utils/sticker.js. Poppins
// Black (900) for headings/BE NAYAK, Poppins SemiBold (600) for body
// text, JetBrains Mono Bold (700) for tabular numerics (vehicle plate
// and extension digits) so every character has a consistent width.
TextStyle _poppins({
  required double size,
  FontWeight weight = FontWeight.w900,
  Color color = _kInk,
  double letterSpacing = 0,
  double? height,
}) =>
    GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle _mono({
  required double size,
  FontWeight weight = FontWeight.w700,
  Color color = _kInk,
  double letterSpacing = 0,
  double? height,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

// Palette — kept in sync with backend/src/utils/sticker.js so the in-app
// preview and the printed vinyl (rendered server-side and downloaded via
// the admin panel) look identical.
const Color _kRed = Color(0xFFE51E25);
const Color _kRedLight = Color(0xFFF26066);
const Color _kRedDark = Color(0xFFB71218);
const Color _kFooterDark = Color(0xFFA61016);
const Color _kPillEdge = Color(0xFF8E0F16);
const Color _kInk = Color(0xFF0F1115);

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
  final int? familyCount;
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

/// Print-ready sticker. Layout mirrors [backend/src/utils/sticker.js] so
/// the in-app preview matches what the admin panel bundles into the ZIP
/// for physical printing. Structure:
///
///   1. Red header (gradient + top gloss)  — QR 4 EMERGENCY / SCAN TO CALL OWNER
///   2. White body
///        - Vehicle number in red (skipped when isManual)
///        - QR flanked by four bold black L-brackets (no more side crosses)
///        - "Extension Number" label
///        - Row: BE NAYAK + red cross + red pill w/ black digits + red cross + BE NAYAK
///   3. Red footer (gradient)
///        - www.qr4emergency.com · support@qr4emergency.com
///        - ACCIDENT | TRACKING | NO PARKING
class _StickerSurface extends StatelessWidget {
  const _StickerSurface({
    required this.alertUrl,
    required this.digits,
    required this.vehicleNumber,
    required this.isManual,
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    final showVehicle = !isManual && vehicleNumber.trim().isNotEmpty;

    return Container(
      width: 460,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            _Body(
              alertUrl: alertUrl,
              digits: digits,
              vehicleNumber: vehicleNumber,
              showVehicle: showVehicle,
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 108,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kRedLight, _kRed, _kRedDark],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Top gloss strip — sells the curved-plastic-badge look.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QR 4 EMERGENCY',
                  textAlign: TextAlign.center,
                  style: _poppins(
                    size: 40,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SCAN TO CALL OWNER',
                  textAlign: TextAlign.center,
                  style: _poppins(
                    size: 15,
                    weight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 2.4,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body({
    required this.alertUrl,
    required this.digits,
    required this.vehicleNumber,
    required this.showVehicle,
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showVehicle) ...[
            Text(
              vehicleNumber.toUpperCase(),
              textAlign: TextAlign.center,
              style: _mono(
                size: 26,
                color: _kRed,
                letterSpacing: 1.5,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),

          // QR + bold black L-brackets at each corner. Stack lets us
          // paint the brackets over a fixed-size QR area.
          SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: QrImageView(
                      data: alertUrl,
                      version: QrVersions.auto,
                      size: 280,
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
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _BracketPainter()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24), // +6 breathing room
          Text(
            'Extension Number',
            textAlign: TextAlign.center,
            style: _poppins(
              size: 17,
              weight: FontWeight.w600,
              letterSpacing: 0.3,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Bottom row: BE NAYAK + cross + pill + cross + BE NAYAK
          SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'BE NAYAK',
                  style: _poppins(
                    size: 20,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
                const _MedicalCross(size: 24),
                _ExtensionPill(digits: digits),
                const _MedicalCross(size: 24),
                Text(
                  'BE NAYAK',
                  style: _poppins(
                    size: 20,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Red pill with black digits — gradient + drop shadow give it the
// "inlaid enamel plate" 3D feel that matches the backend renderer.
class _ExtensionPill extends StatelessWidget {
  const _ExtensionPill({required this.digits});
  final String digits;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF04347), _kRed, Color(0xFFC11821)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPillEdge, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top gloss strip
          Positioned(
            left: 2,
            right: 2,
            top: 2,
            child: Container(
              height: 44 * 0.42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Center(
            child: Text(
              digits.isNotEmpty ? digits : '—',
              style: _mono(
                size: 26,
                letterSpacing: 1.5,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kRed, _kFooterDark],
        ),
        // 1.5px inset shadow along the top seam so the footer reads as
        // physically layered under the white body rather than glued flat.
        border: Border(
          top: BorderSide(
            color: Colors.black.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ContactChip(
                icon: Icons.language_rounded,
                label: 'www.qr4emergency.com',
              ),
              _ContactChip(
                icon: Icons.mail_outline_rounded,
                label: 'support@qr4emergency.com',
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FooterBadge(
                icon: Icons.warning_amber_rounded,
                iconColor: Color(0xFFF4B400),
                label: 'ACCIDENT',
              ),
              _FooterDivider(),
              _FooterBadge(
                icon: Icons.location_on_rounded,
                iconColor: Colors.white,
                label: 'TRACKING',
              ),
              _FooterDivider(),
              _FooterBadge(
                icon: Icons.local_parking_rounded,
                iconColor: Colors.white,
                label: 'NO PARKING',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          // 12pt keeps "support@qr4emergency.com" comfortably inside the
          // sticker width alongside the website chip. Bumping this any
          // higher pushes the closing ".com" past the right margin.
          style: _poppins(
            size: 12,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: Colors.white.withValues(alpha: 0.55),
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
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: _poppins(
            size: 13,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// Bold black L-shaped brackets at the four corners of the QR frame.
/// Painted as filled rectangles (not thin strokes) to match the
/// backend SVG's 8px-thick × 42px-arm brackets — bumped from 6 so the
/// bracket weight balances better against the QR modules.
class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  static const double _arm = 42;
  static const double _thick = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kInk
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Top-left: horizontal + vertical arm
    canvas.drawRect(Rect.fromLTWH(0, 0, _arm, _thick), paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, _thick, _arm), paint);
    // Top-right
    canvas.drawRect(Rect.fromLTWH(w - _arm, 0, _arm, _thick), paint);
    canvas.drawRect(Rect.fromLTWH(w - _thick, 0, _thick, _arm), paint);
    // Bottom-left
    canvas.drawRect(Rect.fromLTWH(0, h - _thick, _arm, _thick), paint);
    canvas.drawRect(Rect.fromLTWH(0, h - _arm, _thick, _arm), paint);
    // Bottom-right
    canvas.drawRect(Rect.fromLTWH(w - _arm, h - _thick, _arm, _thick), paint);
    canvas.drawRect(Rect.fromLTWH(w - _thick, h - _arm, _thick, _arm), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Red medical/emergency cross with a subtle white highlight strip on
/// each arm, mirroring the backend's enamel-plate 3D feel.
class _MedicalCross extends StatelessWidget {
  const _MedicalCross({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final barThickness = size * 0.32;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base cross with drop shadow — two overlapping bars.
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 2.5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: barThickness,
                    height: size,
                    color: _kRed,
                  ),
                  Container(
                    width: size,
                    height: barThickness,
                    color: _kRed,
                  ),
                ],
              ),
            ),
          ),
          // Highlight strips (enamel gloss).
          Positioned(
            top: 0.6,
            child: Container(
              width: barThickness - 1.2,
              height: size * 0.18,
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            left: 0.6,
            child: Container(
              width: size - 1.2,
              height: barThickness * 0.35,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}
