import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/session_store.dart';
import '../home/home_tab.dart';
import '../history/history_tab.dart';
import '../profile/profile_tab.dart' show ProfileTab, ProfileTabState;
import '../qr/qr_flow_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _qrInner = false;
  final GlobalKey<QrFlowTabState> _qrKey = GlobalKey<QrFlowTabState>();
  // Attached to HistoryTab so we can force a re-fetch every time the user
  // switches back to it. IndexedStack keeps the widget mounted, so its
  // initState() only fires once for the whole app session.
  final GlobalKey<HistoryTabState> _historyKey = GlobalKey<HistoryTabState>();
  // Same trick for Profile — the tab shows stale data otherwise (a common
  // "why is my email old?" complaint after editing on another device).
  final GlobalKey<ProfileTabState> _profileKey = GlobalKey<ProfileTabState>();

  Future<void> _logout() async {
    // Best-effort server notify before dropping the local token. If the
    // network is down or the token is already expired, fall through and
    // clear local state anyway — the user expects logout to always succeed.
    try {
      await ApiClient.instance.post('/auth/logout', const <String, dynamic>{});
    } catch (_) {
      // intentionally swallowed
    }
    await SessionStore.clear();
    if (!mounted) return;
    widget.onLogout();
  }

  void _setIndex(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    // Focus-refresh: whenever the user navigates onto the History or
    // Profile tab, pull fresh data. IndexedStack keeps the widget alive
    // so initState only fires once for the whole session — without this
    // the tab shows whatever was cached at first mount.
    if (i == 2) {
      _historyKey.currentState?.refresh();
    } else if (i == 3) {
      _profileKey.currentState?.refresh();
    }
  }

  void _setQrInner(bool v) {
    if (_qrInner == v) return;
    setState(() => _qrInner = v);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101729),
        title: const Text(
          'Exit app?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Are you sure you want to close QR 4 Emergency?',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Exit',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handleSystemBack() async {
    // QR tab is on an inner stage → step back through its state machine.
    if (_index == 1) {
      final consumed = _qrKey.currentState?.stepBack() ?? false;
      if (consumed) return;
    }

    // Any other tab on a non-home index → return to home instead of exiting.
    if (_index != 0) {
      _setIndex(0);
      return;
    }

    // On the home landing → ask before closing.
    if (await _confirmExit()) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideNav = _index == 1 && _qrInner;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            HomeTab(
              onOpenQr: () => _setIndex(1),
            ),
            QrFlowTab(
              key: _qrKey,
              onInnerChanged: _setQrInner,
              onRequestHome: () => _setIndex(0),
            ),
            HistoryTab(key: _historyKey),
            ProfileTab(key: _profileKey, onLogout: _logout),
          ],
        ),
        bottomNavigationBar:
            hideNav ? null : _PremiumNav(index: _index, onTap: _setIndex),
      ),
    );
  }
}

class _PremiumNav extends StatelessWidget {
  const _PremiumNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = <_NavItem>[
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.qr_code_2_rounded, 'QR'),
    _NavItem(Icons.history_rounded, 'History'),
    _NavItem(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final item = _items[i];
                  final selected = i == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: selected ? AppColors.brandGradient : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.6),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                    spreadRadius: -8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                item.icon,
                                size: 18,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              Text(
                                item.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
