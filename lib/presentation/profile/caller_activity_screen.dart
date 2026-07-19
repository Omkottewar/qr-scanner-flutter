import 'package:flutter/material.dart';

import '../../core/ist_time.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/glass_card.dart';

class CallerActivityScreen extends StatefulWidget {
  const CallerActivityScreen({super.key});

  @override
  State<CallerActivityScreen> createState() => _CallerActivityScreenState();
}

class _CallerActivityScreenState extends State<CallerActivityScreen> {
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
      // Always request masked numbers. Bystanders never signed up to have
      // their personal numbers exposed to the QR owner — treat their
      // digits as sensitive, no unmask.
      final res = await ApiClient.instance
          .get('/profile/caller-activity') as Map<String, dynamic>;
      final raw = (res['items'] as List<dynamic>?) ?? const [];
      if (!mounted) return;
      setState(() {
        _items = raw
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? dateStr) {
    final utc = IstTime.parseUtc(dateStr);
    if (utc == null) return (dateStr == null || dateStr.isEmpty) ? '—' : dateStr;
    final ist = IstTime.toIst(utc);
    final hh = ist.hour.toString().padLeft(2, '0');
    final mm = ist.minute.toString().padLeft(2, '0');
    return '${ist.day} ${IstTime.monthsShort[ist.month - 1]} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06090F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Caller Activity',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
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
        padding: const EdgeInsets.all(24),
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
            child: const Icon(Icons.phone_disabled_rounded,
                size: 42, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No callers yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Callers who reach your QR through the bridge will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: _items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ActivityCard(
          row: _items[i],
          formatDate: _formatDate,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.row,
    required this.formatDate,
  });

  final Map<String, dynamic> row;
  final String Function(String?) formatDate;

  @override
  Widget build(BuildContext context) {
    final isBlocked = row['is_blocked'] == true || row['is_blocked'] == 1;
    final count = row['call_count'] is int
        ? row['call_count'] as int
        : int.tryParse('${row['call_count']}') ?? 0;
    // Prefer new API field name; fall back to legacy one for backward compat.
    final caller = (row['from_number'] ?? row['caller_number'])?.toString() ?? '—';
    final vehicle = row['vehicle_number']?.toString() ?? '—';
    final last = formatDate(row['last_call_at']?.toString());
    final suspicious = count >= 5;

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
                  color: (isBlocked
                          ? const Color(0xFFEF4444)
                          : suspicious
                              ? AppColors.amber
                              : AppColors.primary)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isBlocked
                            ? const Color(0xFFEF4444)
                            : suspicious
                                ? AppColors.amber
                                : AppColors.primary)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  isBlocked
                      ? Icons.block_rounded
                      : suspicious
                          ? Icons.warning_amber_rounded
                          : Icons.phone_in_talk_rounded,
                  color: isBlocked
                      ? const Color(0xFFEF4444)
                      : suspicious
                          ? AppColors.amber
                          : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caller,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$vehicle · last $last',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (suspicious ? AppColors.amber : AppColors.primary)
                      .withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        color: suspicious ? AppColors.amber : AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      count == 1 ? 'call' : 'calls',
                      style: TextStyle(
                        color: suspicious ? AppColors.amber : AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  isBlocked
                      ? 'Blocked. Future calls to this QR will be rejected.'
                      : suspicious
                          ? 'Flagged as suspicious — 5 or more calls.'
                          : 'Normal activity.',
                  style: TextStyle(
                    color: isBlocked
                        ? const Color(0xFFEF4444)
                        : suspicious
                            ? AppColors.amber
                            : AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (!isBlocked && suspicious) ...[
            const SizedBox(height: 8),
            const Text(
              'To block this caller, open History → Call Logs and tap Block on any of their entries.',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
