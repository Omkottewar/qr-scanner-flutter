import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import 'ea_card.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await ApiClient.instance.get('/profile');
      if (profile == null || profile is! Map) {
        throw Exception('Failed to load user profile');
      }

      final userId = profile['id'];
      if (userId == null) {
        throw Exception('User ID not found in profile');
      }

      final res = await ApiClient.instance.get('/api/notifications/user/$userId');
      if (res is Map && res['items'] != null) {
        if (mounted) {
          setState(() {
            _items = List<dynamic>.from(res['items']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int notificationId, int index) async {
    try {
      final res = await ApiClient.instance.put('/api/notifications/read/$notificationId', {});
      if (res != null && mounted) {
        setState(() {
          _items[index]['isRead'] = true;
        });
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  String _formatDateTime(String dtStr) {
    try {
      final parsed = DateTime.parse(dtStr).toLocal();
      final year = parsed.year;
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    } catch (_) {
      return dtStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load notifications',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton.icon(
                          onPressed: _loadNotifications,
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                          label: const Text('Retry', style: TextStyle(color: AppColors.primary)),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(32),
                        children: [
                          const SizedBox(height: 80),
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: AppColors.textSecondary.withOpacity(0.35),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No notifications yet',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Alerts sent by admin or security triggers will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index] as Map<String, dynamic>;
                          final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                          final title = item['title']?.toString() ?? 'Notification';
                          final message = item['message']?.toString() ?? '';
                          final isRead = item['isRead'] == true || item['isRead'] == 1 || item['isRead'] == 'true';
                          final dateStr = item['createdAt']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                if (!isRead && id > 0) {
                                  _markAsRead(id, index);
                                }
                              },
                              child: EaCard(
                                background: isRead ? AppColors.card : AppColors.card.withOpacity(0.85),
                                border: isRead
                                    ? Border.all(color: Colors.white10)
                                    : Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? AppColors.inputFill
                                            : AppColors.primary.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isRead
                                            ? Icons.notifications_none_rounded
                                            : Icons.notifications_active_rounded,
                                        color: isRead ? AppColors.textSecondary : AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: AppColors.textPrimary,
                                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatDateTime(dateStr),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
      ),
    );
  }
}
