import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import 'notification_list_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.compact = false});

  /// When true, renders a bare icon + dot (no IconButton padding),
  /// suitable for embedding inside a fixed-size glass circle.
  final bool compact;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (!mounted) return;
    try {
      final profile = await ApiClient.instance.get('/profile');
      if (profile is Map) {
        final userId = profile['id'];
        if (userId != null) {
          final res = await ApiClient.instance.get('/api/notifications/user/$userId');
          if (res is Map && res['items'] != null) {
            final items = List<dynamic>.from(res['items']);
            final unread = items
                .where((item) => item['isRead'] == false || item['isRead'] == 0)
                .length;
            if (mounted) setState(() => _unreadCount = unread);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications count: $e');
    }
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationListScreen(),
      ),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_outlined,
              size: 18,
              color: AppColors.textPrimary,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              size: 26, color: AppColors.textPrimary),
          onPressed: _open,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
