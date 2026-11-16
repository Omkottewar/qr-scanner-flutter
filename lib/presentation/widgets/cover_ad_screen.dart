import 'dart:async';

import 'package:flutter/material.dart';

/// Full-screen cover ad shown as the very first thing on app launch.
/// Auto-dismisses after [displayDuration]; a Skip button fades in once
/// [skipAfter] has elapsed so users can bail early.
class CoverAdScreen extends StatefulWidget {
  const CoverAdScreen({
    super.key,
    required this.onDismiss,
    this.displayDuration = const Duration(seconds: 6),
    this.skipAfter = const Duration(seconds: 2),
  });

  final VoidCallback onDismiss;
  final Duration displayDuration;
  final Duration skipAfter;

  @override
  State<CoverAdScreen> createState() => _CoverAdScreenState();
}

class _CoverAdScreenState extends State<CoverAdScreen> {
  Timer? _autoDismiss;
  Timer? _skipReveal;
  bool _showSkip = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(widget.displayDuration, _dismiss);
    _skipReveal = Timer(widget.skipAfter, () {
      if (!mounted) return;
      setState(() => _showSkip = true);
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _skipReveal?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/coverad.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Positioned(
            top: padding.top + 12,
            right: 12,
            child: AnimatedOpacity(
              opacity: _showSkip ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showSkip,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _dismiss,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
