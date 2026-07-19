import 'package:flutter/material.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../qr/qr_view_screen.dart';
import '../widgets/glass_card.dart';
import '../widgets/scale_tap.dart';
import '../../data/session_store.dart';
import 'call_history_tab.dart';
import 'edit_family_screen.dart';
import 'renew_sheet.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => HistoryTabState();
}

// Exposed publicly so MainShell can call refresh() via a GlobalKey when
// the user re-focuses the History tab — IndexedStack keeps the widget
// mounted, so initState() only fires once and stale data hangs around
// without an explicit re-fetch.
class HistoryTabState extends State<HistoryTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  final Set<int> _deletingIds = <int>{};
  // Attached to the CallHistoryTab child so we can trigger its refresh
  // in lockstep with the QR list — otherwise a user sitting on the
  // "Call Logs" sub-tab keeps seeing stale rows after a real call.
  final GlobalKey<CallHistoryTabState> _callsKey =
      GlobalKey<CallHistoryTabState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public re-fetch — called by MainShell on tab focus. Refreshes both
  /// the QR list AND the Call Logs sub-tab so whichever sub-tab the user
  /// is looking at is up-to-date.
  Future<void> refresh() async {
    _callsKey.currentState?.refresh();
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get('/qr/history');
      if (!mounted) return;
      // Explicit shape check — an unauthenticated 401 response, or the
      // API returning a plain string, would otherwise blow up on the
      // `as Map` cast with a confusing stack trace.
      if (res is! Map) {
        throw Exception('Unexpected server response for QR history');
      }
      final items = (res['items'] as List<dynamic>?) ?? const [];
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _activeCount => _items
      .where(
        (r) => (r as Map)['is_active'] == true || r['is_active'] == 1,
      )
      .length;

  // Opens the renewal bottom sheet for the tapped QR. On success (true)
  // we refresh so the "VALID UNTIL" tile and ACTIVE/EXPIRED pill update
  // immediately.
  Future<void> _openRenew(Map<String, dynamic> row) async {
    final id = (row['id'] is int)
        ? row['id'] as int
        : int.tryParse(row['id']?.toString() ?? '');
    if (id == null) return;
    final mobile = await SessionStore.getMobile() ?? '';
    if (!mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RenewSheet(
        qrId: id,
        vehicleNumber: row['vehicle_number']?.toString() ?? '',
        userMobile: mobile,
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR renewed for another year')),
      );
      await _load();
    }
  }

  // Confirm + DELETE /qr/:id. Backend cascade removes qrdata + family +
  // alerts + call logs + caller_activity. The users row is preserved.
  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = (row['id'] is int)
        ? row['id'] as int
        : int.tryParse(row['id']?.toString() ?? '');
    if (id == null) return;
    final vehicle = row['vehicle_number']?.toString() ?? 'this QR';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent, size: 30),
        ),
        title: Text('Delete $vehicle?', textAlign: TextAlign.center),
        content: const Text(
          'This will permanently remove the QR, its emergency contacts, alerts, and call history. '
          'You cannot undo this.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingIds.add(id));
    try {
      await ApiClient.instance.delete('/qr/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$vehicle deleted')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed. ${ErrorMessages.friendly(e)}')));
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(id));
    }
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final id = (row['id'] is int)
        ? row['id'] as int
        : int.tryParse(row['id']?.toString() ?? '');
    if (id == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditFamilyScreen(
          qrId: id,
          ownerName: row['name']?.toString() ?? '',
          vehicleNumber: row['vehicle_number']?.toString() ?? '',
          ownerPhone: row['mobile']?.toString() ?? '',
        ),
      ),
    );
    if (updated == true) _load();
  }

  void _openView(Map<String, dynamic> row) {
    final alertUrl = row['alert_url']?.toString() ?? '';
    if (alertUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert link missing — pull to refresh.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrViewScreen(
          alertUrl: alertUrl,
          digits: row['digits']?.toString() ?? '',
          vehicleNumber: row['vehicle_number']?.toString() ?? '',
          ownerName: row['name']?.toString() ?? '',
          bloodGroup: row['blood_group']?.toString() ?? '',
          familyCount: row['family_count'] is int
              ? row['family_count'] as int
              : int.tryParse('${row['family_count']}'),
          // Manual QRs are printed before the vehicle is known, so the
          // in-app sticker matches the physical one by hiding the
          // vehicle line. is_manual comes straight from qrdata.
          isManual: row['is_manual'] == true || row['is_manual'] == 1,
        ),
      ),
    );
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
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _Heading(),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: _GlassTabBar(),
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _QrTab(
                          loading: _loading,
                          error: _error,
                          items: _items,
                          activeCount: _activeCount,
                          deletingIds: _deletingIds,
                          onRetry: _load,
                          onRefresh: _load,
                          onEdit: _openEdit,
                          onView: _openView,
                          onDelete: _confirmDelete,
                          onRenew: _openRenew,
                        ),
                        CallHistoryTab(key: _callsKey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF06090F))),
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
                      AppColors.primary.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
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
          'Track your QR codes and emergency calls',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: TabBar(
          indicator: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelPadding: const EdgeInsets.symmetric(vertical: 10),
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'QR Codes'),
            Tab(text: 'Call Logs'),
          ],
        ),
      ),
    );
  }
}

class _QrTab extends StatelessWidget {
  const _QrTab({
    required this.loading,
    required this.error,
    required this.items,
    required this.activeCount,
    required this.deletingIds,
    required this.onRetry,
    required this.onRefresh,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onRenew,
  });

  final bool loading;
  final String? error;
  final List<dynamic> items;
  final int activeCount;
  final Set<int> deletingIds;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onView;
  final void Function(Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>) onRenew;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 140),
                Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ],
            )
          : error != null
              ? _ErrorState(message: error!, onRetry: onRetry)
              : items.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 128),
                      children: [
                        _OverviewCard(total: items.length, active: activeCount),
                        const SizedBox(height: 20),
                        for (final row in items) ...[
                          Builder(builder: (_) {
                            final r = row as Map<String, dynamic>;
                            final id = r['id'] is int
                                ? r['id'] as int
                                : int.tryParse(r['id']?.toString() ?? '');
                            final deleting =
                                id != null && deletingIds.contains(id);
                            return _QrCard(
                              row: r,
                              deleting: deleting,
                              onEdit: () => onEdit(r),
                              onView: () => onView(r),
                              onDelete: () => onDelete(r),
                              onRenew: () => onRenew(r),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.total, required this.active});
  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.6),
              blurRadius: 50,
              spreadRadius: -16,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR CODE OVERVIEW',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have $active active out of $total total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _stat('TOTAL', total),
                const SizedBox(width: 8),
                _stat('ACTIVE', active),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.row,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onRenew,
    required this.deleting,
  });
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onRenew;
  final bool deleting;

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    var s = dateStr;
    final hasOffset =
        s.endsWith('Z') || RegExp(r'[+\-]\d{2}:?\d{2}$').hasMatch(s);
    if (!hasOffset) s = '${s}Z';
    final d = DateTime.tryParse(s)?.toLocal();
    if (d == null) return dateStr;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final activatedStr = row['date_of_activation']?.toString();
    final activatedDate = DateTime.tryParse(activatedStr ?? '');
    final activated = _formatDate(activatedStr);
    final validUntil = activatedDate != null
        ? _formatDate(DateTime(
                activatedDate.year + 1, activatedDate.month, activatedDate.day)
            .toIso8601String())
        : '—';
    final isActive = row['is_active'] == true || row['is_active'] == 1;
    final isManual = row['is_manual'] == true || row['is_manual'] == 1;
    // A QR is expired if the server-side flag is off, OR the 365-day window
    // has elapsed since activation (safety net for the window between real
    // expiry and the scheduler flipping is_active).
    final overOneYear = activatedDate != null &&
        DateTime.now().difference(activatedDate).inDays > 365;
    final isExpired = !isActive || overOneYear;
    // Renewal UI is deliberately not rendered — the product is a
    // one-time purchase with no annual renewal. The onRenew callback
    // chain is kept wired all the way through so the feature can be
    // brought back later with a single-line UI change if the business
    // model changes.

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['name']?.toString() ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NK-${(row['unique_id']?.toString() ?? '').toUpperCase().substring(
                            0,
                            ((row['unique_id']?.toString() ?? '').length).clamp(0, 6),
                          )}',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              _SourceChip(isManual: isManual),
              const SizedBox(width: 6),
              _StatusDot(active: isActive && !isExpired, expired: isExpired),
              const SizedBox(width: 4),
              // Delete affordance. Opens a confirm dialog; on Yes the
              // backend cascade-deletes qrdata + family + alerts + logs.
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: deleting ? null : onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: _Hairline(),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              _MetaTile(
                icon: Icons.directions_car_rounded,
                label: 'VEHICLE',
                value: row['vehicle_number']?.toString() ?? '—',
              ),
              _MetaTile(
                icon: Icons.bloodtype_rounded,
                label: 'BLOOD',
                value: row['blood_group']?.toString() ?? '—',
              ),
              _MetaTile(
                icon: Icons.event_available_rounded,
                label: 'ACTIVATED',
                value: activated,
              ),
              _MetaTile(
                icon: Icons.schedule_rounded,
                label: 'VALID UNTIL',
                value: validUntil,
              ),
            ],
          ),
          // Renewal banner was here — removed while the product is a
          // one-time purchase. The onRenew callback plumbing is still
          // wired through _QrTab / _QrCard so re-enabling is a
          // one-block edit if renewal comes back.
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ScaleTap(
                  onTap: onView,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 14,
                          spreadRadius: -4,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 8),
                        Text(
                          'View QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaleTap(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded,
                            color: AppColors.amber, size: 15),
                        SizedBox(width: 8),
                        Text(
                          'Edit Contacts',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 13),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.isManual});
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    final color = isManual ? const Color(0xFF8B5CF6) : AppColors.amber;
    final label = isManual ? 'MANUAL' : 'AUTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, this.expired = false});
  final bool active;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    // Expired takes precedence over the plain active/inactive split so
    // the owner sees "EXPIRED" (deep red) instead of a vague "INACTIVE".
    final Color color;
    final String label;
    if (expired) {
      color = const Color(0xFFDC2626);
      label = 'EXPIRED';
    } else if (active) {
      color = const Color(0xFF10B981);
      label = 'ACTIVE';
    } else {
      color = const Color(0xFFEF4444);
      label = 'INACTIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const SizedBox(height: 80),
        Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 100),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded,
              size: 42, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 20),
        const Text(
          'No QR codes yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your generated QR codes will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline_rounded,
            size: 56, color: Color(0xFFEF4444)),
        const SizedBox(height: 16),
        const Text(
          'Something went wrong',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
