import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'call_history_tab.dart';

/// Standalone "History" page — just the emergency call logs. No link to
/// the QR codes list (that lives on its own page). MainShell drives it
/// through [CallHistoryPageState.refresh] on tab focus.
class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

  @override
  State<CallHistoryPage> createState() => CallHistoryPageState();
}

class CallHistoryPageState extends State<CallHistoryPage> {
  final GlobalKey<CallHistoryTabState> _childKey =
      GlobalKey<CallHistoryTabState>();

  Future<void> refresh() async {
    _childKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _AmbientBg(),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Heading(),
                  ),
                ),
                Expanded(child: CallHistoryTab(key: _childKey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Review your emergency call logs',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AmbientBg extends StatelessWidget {
  const _AmbientBg();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
          ),
          Positioned(
            top: -120,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.75],
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
