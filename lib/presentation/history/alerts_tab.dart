import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error_messages.dart';
import '../../core/ist_time.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/glass_card.dart';
import '../widgets/scale_tap.dart';

/// The "Alerts" sub-tab under History. Shows every tap a bystander has made
/// on the alert page for any QR the user owns, with optional GPS location.
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await ApiClient.instance.get('/profile/alerts') as Map<String, dynamic>;
      final raw = (res['items'] as List<dynamic>?) ?? const [];
      if (!mounted) return;
      setState(() {
        _items = raw
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      });
    } catch (e) {
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

  Future<void> _dismiss(int id) async {
    try {
      await ApiClient.instance.post(
        '/profile/alerts/$id/dismiss',
        const <String, dynamic>{},
      );
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((r) => r['id'] == id);
        if (idx >= 0) {
          _items = List<Map<String, dynamic>>.from(_items);
          _items[idx] = Map<String, dynamic>.from(_items[idx])
            ..['seen_at'] = DateTime.now().toIso8601String();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      }
    }
  }

  String _relativeTime(String? iso) {
    final utc = IstTime.parseUtc(iso);
    if (utc == null) return (iso == null || iso.isEmpty) ? '—' : iso;
    final diff = IstTime.since(utc);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final ist = IstTime.toIst(utc);
    return '${ist.day} ${IstTime.monthsShort[ist.month - 1]}';
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
          Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              label: const Text(
                'Retry',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
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
            child: const Icon(Icons.location_off_rounded,
                size: 42, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No alerts yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'When someone scans your QR and taps a contact, you\'ll see the tap and their location here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 128),
      itemCount: _items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _AlertCard(
          row: _items[i],
          onOpenMap: _openMap,
          onDismiss: _dismiss,
          relativeTime: _relativeTime,
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.row,
    required this.onOpenMap,
    required this.onDismiss,
    required this.relativeTime,
  });

  final Map<String, dynamic> row;
  final void Function(double lat, double lng) onOpenMap;
  final void Function(int id) onDismiss;
  final String Function(String?) relativeTime;

  @override
  Widget build(BuildContext context) {
    final id = row['id'] is int
        ? row['id'] as int
        : int.tryParse('${row['id']}') ?? 0;
    final vehicle = row['vehicle_number']?.toString() ?? '—';
    final kind = row['contact_kind']?.toString() ?? '';
    final famRel = row['contact_family_relation']?.toString();
    final famName = row['contact_family_name']?.toString();
    final createdAt = row['created_at']?.toString();
    final seen = row['seen_at'] != null;

    final lat = _asDouble(row['latitude']);
    final lng = _asDouble(row['longitude']);
    final accuracy = _asDouble(row['accuracy_meters']);
    final hasLocation = lat != null && lng != null;

    String contactLabel;
    if (kind == 'owner') {
      contactLabel = 'You (owner)';
    } else if (kind == 'family' && (famRel != null || famName != null)) {
      contactLabel = famRel != null && famName != null
          ? '$famRel — $famName'
          : (famRel ?? famName!);
    } else if (kind == 'family') {
      contactLabel = 'Family contact (removed)';
    } else {
      contactLabel = 'Unknown';
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (seen
                          ? AppColors.textTertiary
                          : (hasLocation ? AppColors.primary : AppColors.amber))
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (seen
                            ? AppColors.textTertiary
                            : (hasLocation ? AppColors.primary : AppColors.amber))
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                  color: seen
                      ? AppColors.textTertiary
                      : (hasLocation ? AppColors.primary : AppColors.amber),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tapped: $contactLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  relativeTime(createdAt),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 12),
          if (hasLocation) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    accuracy != null
                        ? 'Location shared · ±${accuracy.round()} m'
                        : 'Location shared',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleTap(
                  onTap: () => onOpenMap(lat, lng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(999),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'View on Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Location not shared — the scanner denied the location prompt.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (!seen) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onDismiss(id),
                child: const Text(
                  'Mark as seen',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}
