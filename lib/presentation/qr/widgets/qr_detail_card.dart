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
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  final String ownerName;
  final String bloodGroup;
  final int? familyCount; // shown as "N EMERGENCY BRANCHES"; hidden if null

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
          Center(
            child: RepaintBoundary(
              key: _captureKey,
              child: _StickerSurface(
                alertUrl: widget.alertUrl,
                digits: widget.digits,
                vehicleNumber: widget.vehicleNumber,
                familyCount: widget.familyCount,
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

/// Print-ready windshield sticker. Clean red-and-white layout — no side
/// strips, no corner cutouts, no double borders. Rasterised on tap of
/// Download / Share, so every pixel here ships on the physical vinyl.
class _StickerSurface extends StatelessWidget {
  const _StickerSurface({
    required this.alertUrl,
    required this.digits,
    required this.vehicleNumber,
    required this.familyCount,
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  // ignore: unused_element_parameter
  final int? familyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — solid red band with a phone glyph in a white circle.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              color: _kEmergencyRed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_rounded,
                        size: 16, color: _kEmergencyRed),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'QR 4 Emergency',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Be Nayak',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body — vehicle number, QR, extension pill.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vehicleNumber.isNotEmpty) ...[
                    Text(
                      'Vehicle No.',
                      style: TextStyle(
                        color: _kInk.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicleNumber,
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // QR — clean white background, thin ink-coloured frame.
                  SizedBox.square(
                    dimension: 224,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _kInk.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: alertUrl,
                        version: QrVersions.auto,
                        size: 206,
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
                  if (digits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Extension Number',
                      style: TextStyle(
                        color: _kInk.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kEmergencyRed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        digits,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Footer — "SCAN TO CALL OWNER" band + subtle Nayak® credit.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: _kEmergencyRed,
              alignment: Alignment.center,
              child: const Text(
                'SCAN TO CALL OWNER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.white,
              alignment: Alignment.center,
              child: Text(
                'Nayak ®',
                style: TextStyle(
                  color: _kInk.withValues(alpha: 0.35),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
