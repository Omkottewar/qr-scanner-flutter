// ignore: unnecessary_import — material.dart doesn't re-export ImageFilter
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/session_store.dart';
import '../home/home_tab.dart';
import '../history/call_history_page.dart';
import '../history/history_tab.dart';
import '../profile/profile_tab.dart' show ProfileTab, ProfileTabState;
import '../qr/qr_flow_tab.dart';
import '../widgets/scale_tap.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.onLogout,
    this.updateAvailable = false,
    this.updateLatestVersion = '',
    this.updateMessage = '',
    this.updatePlayStoreUrl = '',
  });

  final VoidCallback onLogout;

  // Soft-update signal from main.dart's boot version check. Non-blocking:
  // HomeTab renders a dismissible banner when `updateAvailable` is true.
  final bool updateAvailable;
  final String updateLatestVersion;
  final String updateMessage;
  final String updatePlayStoreUrl;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Index map — now five fully independent pages, no shared tab bars:
  //   0 Home · 1 QR scan · 2 My QR · 3 History · 4 Profile
  int _index = 0;
  bool _qrInner = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<QrFlowTabState> _qrKey = GlobalKey<QrFlowTabState>();
  // Re-fetch keys. IndexedStack keeps each child mounted, so initState()
  // only fires once for the whole app session — these let us trigger a
  // refresh on focus instead of showing stale cached data.
  final GlobalKey<HistoryTabState> _myQrKey = GlobalKey<HistoryTabState>();
  final GlobalKey<CallHistoryPageState> _callHistoryKey =
      GlobalKey<CallHistoryPageState>();
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
    // Focus-refresh: pull fresh data for whichever page the user just
    // moved onto.
    switch (i) {
      case 2:
        _myQrKey.currentState?.refresh();
      case 3:
        _callHistoryKey.currentState?.refresh();
      case 4:
        _profileKey.currentState?.refresh();
    }
  }

  void _setQrInner(bool v) {
    if (_qrInner == v) return;
    setState(() => _qrInner = v);
  }

  void _openDrawer() {
    HapticFeedback.selectionClick();
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
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
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
              ),
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
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        extendBody: true,
        drawer: _SideDrawer(
          onNavigate: (i) {
            Navigator.of(context).pop(); // close the drawer first
            _setIndex(i);
          },
          onLogout: () async {
            Navigator.of(context).pop();
            await _logout();
          },
        ),
        body: IndexedStack(
          index: _index,
          children: [
            HomeTab(
              onOpenQr: () => _setIndex(1),
              onOpenDrawer: _openDrawer,
              updateAvailable: widget.updateAvailable,
              updateLatestVersion: widget.updateLatestVersion,
              updateMessage: widget.updateMessage,
              updatePlayStoreUrl: widget.updatePlayStoreUrl,
            ),
            QrFlowTab(
              key: _qrKey,
              onInnerChanged: _setQrInner,
              onRequestHome: () => _setIndex(0),
            ),
            HistoryTab(key: _myQrKey),
            CallHistoryPage(key: _callHistoryKey),
            ProfileTab(key: _profileKey, onLogout: _logout),
          ],
        ),
        bottomNavigationBar:
            hideNav ? null : _PremiumNav(index: _index, onTap: _setIndex),
      ),
    );
  }
}

// Nav slots: five real destinations, each a separate page in the
// IndexedStack. No shared tab bar or slider between My QR and History.
//   Home (0) · My QR (2) · [Scan center 1] · History (3) · Profile (4)
class _PremiumNav extends StatelessWidget {
  const _PremiumNav({
    required this.index,
    required this.onTap,
  });
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // The nav sits in a floating pill above the body. Without a backdrop,
    // the rounded corners of the pill + the space between the pill and
    // screen edges would let scrolled content bleed through from below.
    // A full-width BackdropFilter under everything frosts the whole bottom
    // region so the floating pill always sits on a clean, blurred strip
    // regardless of what's underneath.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.white.withValues(alpha: 0.72),
          child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        // Taller box so the raised scan button has room to float above
        // the pill without clipping.
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.hairline),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavSlot(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        selected: index == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavSlot(
                        icon: Icons.receipt_long_rounded,
                        label: 'My QR',
                        selected: index == 2,
                        onTap: () => onTap(2),
                      ),
                      // Spacer column reserved for the floating scan
                      // button sitting above the pill.
                      const SizedBox(width: 72),
                      _NavSlot(
                        icon: Icons.history_rounded,
                        label: 'History',
                        selected: index == 3,
                        onTap: () => onTap(3),
                      ),
                      _NavSlot(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        selected: index == 4,
                        onTap: () => onTap(4),
                      ),
                    ],
                  ),
                ),
              ),
              // Raised, extra-bold scan button. White ring + heavy shadow
              // + larger icon so it clearly reads as the primary action.
              Positioned(
                bottom: 20,
                child: _ScanSlot(
                  selected: index == 1,
                  onTap: () => onTap(1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),      // SafeArea
          ),  // Container (frosted tint)
        ),    // BackdropFilter
    );        // ClipRect
  }
}

// Elevated primary action — QR scan. Oversized raised disc with a white
// outer ring + heavy shadow for a bold presence.
class _ScanSlot extends StatelessWidget {
  const _ScanSlot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              // Thick white outer ring plus heavy brand-tinted shadow —
              // this is the "bold" center the user asked for.
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 34,
              weight: 900,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Scan',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Side drawer — opens from the brand logo tap in the top-left of the home
// screen. Lists the five destinations, a divider, and a logout action. All
// callbacks are provided by MainShell so the drawer stays dumb.
// -----------------------------------------------------------------------------
class _SideDrawer extends StatelessWidget {
  const _SideDrawer({required this.onNavigate, required this.onLogout});

  final ValueChanged<int> onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/nayak.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'QR 4 Emergency',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'BE NAYAK',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.home_rounded,
              label: 'Home',
              onTap: () => onNavigate(0),
            ),
            _DrawerItem(
              icon: Icons.receipt_long_rounded,
              label: 'My QR',
              onTap: () => onNavigate(2),
            ),
            _DrawerItem(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan',
              onTap: () => onNavigate(1),
            ),
            _DrawerItem(
              icon: Icons.history_rounded,
              label: 'History',
              onTap: () => onNavigate(3),
            ),
            _DrawerItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              onTap: () => onNavigate(4),
            ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              destructive: true,
              onTap: onLogout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.red : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
