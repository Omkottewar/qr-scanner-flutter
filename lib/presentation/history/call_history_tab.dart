import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error_messages.dart';
import '../../core/ist_time.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/ea_card.dart';

/// Call Logs sub-tab under History.
///
/// Backed by `GET /profile/call-logs` which returns one row per completed
/// Exotel call attributed to a QR the caller owns. Rows carry the caller
/// number (masked), the destination number (masked), duration, times,
/// and an optional geolocation lifted from the alert_events row that
/// triggered the call (10-minute window).
///
/// Row actions:
///   • Show location → opens Google Maps at (lat, lng) if present.
///   • Block         → POST /profile/call-logs/:id/block, flips is_blocked
///                     on the caller_activity row for (qr_id, from_number).
///                     Future Exotel lookups from that caller return an
///                     empty destination.numbers array.
class CallHistoryTab extends StatefulWidget {
  const CallHistoryTab({super.key});

  @override
  State<CallHistoryTab> createState() => CallHistoryTabState();
}

// State is public so HistoryTab can trigger a re-fetch via GlobalKey when
// the main shell brings the History tab back into focus. Without this,
// switching sub-tabs after a fresh call would show stale data.
class CallHistoryTabState extends State<CallHistoryTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  final Set<int> _pendingBlockIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public re-fetch — HistoryTab calls this on tab focus.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Ask for unmasked numbers so the Block button can actually key the
      // right (qr_id, from_number) row on the backend.
      final res =
          await ApiClient.instance.get('/profile/call-logs?reveal=true');
      debugPrint('[call-logs] raw response type: ${res.runtimeType}');
      debugPrint('[call-logs] raw response: $res');

      if (res == null) {
        throw Exception('Empty response from /profile/call-logs');
      }
      if (res is! Map) {
        throw Exception(
            'Unexpected response shape: ${res.runtimeType} (expected Map)');
      }
      final map = Map<String, dynamic>.from(res);
      final raw = (map['items'] as List?) ?? const [];
      debugPrint('[call-logs] parsed ${raw.length} items');

      if (!mounted) return;
      setState(() {
        _items = raw
            .whereType<Map>()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      });
    } catch (e) {
      debugPrint('[call-logs] error: $e');
      if (mounted) setState(() => _error = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Future<void> _block(int id) async {
    // Rapid double-taps and the button-press path both funnel through
    // here — bail out if we're already mid-request for this id.
    if (_pendingBlockIds.contains(id)) return;
    setState(() => _pendingBlockIds.add(id));

    // Optimistic update — mark this row and every other row from the same
    // (qr_id, from_number) as blocked immediately, so the UI reflects the
    // tap instantly without waiting for the network round-trip.
    final idx = _items.indexWhere((r) => r['id'] == id);
    int? qrId;
    Object? fromNumber;
    if (idx >= 0) {
      qrId = _items[idx]['qr_id'] is int
          ? _items[idx]['qr_id'] as int
          : int.tryParse('${_items[idx]['qr_id']}');
      fromNumber = _items[idx]['from_number'];
      setState(() {
        _items = _items.map((r) {
          if (r['qr_id'] == qrId && r['from_number'] == fromNumber) {
            return Map<String, dynamic>.from(r)..['is_blocked'] = true;
          }
          return r;
        }).toList(growable: false);
      });
    }

    try {
      await ApiClient.instance.post(
        '/profile/call-logs/$id/block',
        const <String, dynamic>{},
      );
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caller blocked for this QR')),
        );
      }
      // Then reconcile with the server as the source of truth. If the
      // block succeeded, this is a no-op visually; if it didn't (rare),
      // the optimistic flip gets reverted.
      await _load();
    } catch (e) {
      // Roll back the optimistic update on failure.
      if (mounted && qrId != null) {
        setState(() {
          _items = _items.map((r) {
            if (r['qr_id'] == qrId && r['from_number'] == fromNumber) {
              return Map<String, dynamic>.from(r)..['is_blocked'] = false;
            }
            return r;
          }).toList(growable: false);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not block: $e')));
      }
    } finally {
      if (mounted) setState(() => _pendingBlockIds.remove(id));
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String _formatDateTime(String? dtStr) {
    final utc = IstTime.parseUtc(dtStr);
    if (utc == null) return (dtStr == null || dtStr.isEmpty) ? '—' : dtStr;
    final ist = IstTime.toIst(utc);
    final nowIst = IstTime.toIst(DateTime.now().toUtc());
    final showYear = ist.year != nowIst.year;
    final day = ist.day.toString().padLeft(2, '0');
    final mon = IstTime.monthsShort[ist.month - 1];
    final hh = ist.hour.toString().padLeft(2, '0');
    final mm = ist.minute.toString().padLeft(2, '0');
    // Backend stores call_logs.start_time in UTC. We convert to India
    // Standard Time (+5:30) here and mark it with the "IST" suffix so
    // users don't wonder whether they're seeing UTC or device-local time.
    return showYear
        ? '$day $mon ${ist.year} · $hh:$mm IST'
        : '$day $mon · $hh:$mm IST';
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }
    if (_error != null) {
      return _Error(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return _Empty(onRefresh: _load);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      itemCount: _items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _CallRow(
          row: _items[i],
          pendingBlock: _pendingBlockIds.contains(_items[i]['id']),
          onOpenMap: _openMap,
          onBlock: _block,
          formatDuration: _formatDuration,
          formatDateTime: _formatDateTime,
          asDouble: _asDouble,
        ),
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.row,
    required this.pendingBlock,
    required this.onOpenMap,
    required this.onBlock,
    required this.formatDuration,
    required this.formatDateTime,
    required this.asDouble,
  });

  final Map<String, dynamic> row;
  final bool pendingBlock;
  final void Function(double lat, double lng) onOpenMap;
  final void Function(int id) onBlock;
  final String Function(int) formatDuration;
  final String Function(String?) formatDateTime;
  final double? Function(dynamic) asDouble;

  @override
  Widget build(BuildContext context) {
    final id =
        row['id'] is int ? row['id'] as int : int.tryParse('${row['id']}') ?? 0;
    final vehicle = row['vehicle_number']?.toString() ?? '—';
    final from = row['from_number']?.toString() ?? '—';
    final to = row['to_number']?.toString() ?? '—';
    final duration =
        int.tryParse(row['duration']?.toString() ?? '0') ?? 0;
    final start = row['start_time']?.toString();
    final isBlocked = row['is_blocked'] == true || row['is_blocked'] == 1;

    final lat = asDouble(row['latitude']);
    final lng = asDouble(row['longitude']);
    final hasLocation = lat != null && lng != null;

    final infoRow = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (isBlocked ? AppColors.red : AppColors.stepGreen)
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isBlocked ? AppColors.red : AppColors.stepGreen)
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Icon(
            isBlocked ? Icons.block_rounded : Icons.phone_in_talk_rounded,
            color: isBlocked ? AppColors.red : AppColors.stepGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                style: TextStyle(
                  color: isBlocked
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  decoration: isBlocked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '→ $to',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        _VehicleBadge(label: vehicle),
      ],
    );

    final chipRow = Row(
      children: [
        _Chip(icon: Icons.timer_outlined, label: formatDuration(duration)),
        const SizedBox(width: 6),
        Flexible(
          child: _Chip(
            icon: Icons.event_rounded,
            label: formatDateTime(start),
          ),
        ),
      ],
    );

    final actionRow = Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: hasLocation
                ? Icons.map_rounded
                : Icons.location_off_rounded,
            label: hasLocation ? 'Show Location' : 'No Location',
            enabled: hasLocation,
            primary: true,
            onTap: hasLocation ? () => onOpenMap(lat, lng) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: isBlocked ? Icons.block_rounded : Icons.block_outlined,
            label: isBlocked ? 'Blocked' : 'Block',
            enabled: !isBlocked && !pendingBlock,
            loading: pendingBlock,
            danger: true,
            onTap: (!isBlocked && !pendingBlock)
                ? () => onBlock(id)
                : null,
          ),
        ),
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        infoRow,
        const SizedBox(height: 10),
        chipRow,
        const SizedBox(height: 10),
        Container(
            height: 1,
            color: isBlocked
                ? AppColors.red.withValues(alpha: 0.15)
                : AppColors.hairline),
        const SizedBox(height: 10),
        actionRow,
      ],
    );

    if (!isBlocked) {
      return EaCard(padding: const EdgeInsets.all(14), child: body);
    }

    // Blocked cards get an entirely different visual: bold red banner
    // stripe on top, red-tinted background, dashed red border. Impossible
    // to miss on a scroll.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.red.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: AppColors.red,
              child: Row(
                children: [
                  const Icon(Icons.block_rounded,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CALLER BLOCKED · future calls will be rejected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(14), child: body),
          ],
        ),
      ),
    );
  }
}

class _VehicleBadge extends StatelessWidget {
  const _VehicleBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.loading = false,
    this.primary = false,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool loading;
  final bool primary;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = danger
        ? AppColors.red
        : (primary ? AppColors.primary : AppColors.textSecondary);
    final bg = enabled
        ? base.withValues(alpha: primary && !danger ? 0.15 : 0.10)
        : Colors.white.withValues(alpha: 0.04);
    final border = enabled
        ? base.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: loading
            ? const SizedBox(
                height: 16,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: enabled ? base : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled ? base : AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      children: [
        const SizedBox(height: 60),
        Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 100),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: const Icon(Icons.phone_missed_rounded,
              size: 42, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 20),
        Text(
          'No emergency calls yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'A row appears here once a bystander completes an emergency call through your QR.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            label: const Text(
              'Refresh',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline_rounded,
            size: 56, color: AppColors.red),
        const SizedBox(height: 16),
        Text(
          'Failed to load calls',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
