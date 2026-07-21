import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId!;
    try {
      final data = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(60);
      setState(() {
        _notifications =
            List<Map<String, dynamic>>.from(data as List);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    final uid = SupabaseService.currentUserId!;
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
    await _load();
  }

  Future<void> _markRead(String id) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    setState(() {
      final idx =
          _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) _notifications[idx]['is_read'] = true;
    });
  }

  void _handleTap(Map<String, dynamic> n) {
    _markRead(n['id']);
    final refType = n['reference_type'] as String?;
    final refId = n['reference_id'] as String?;
    if (refType == null || refId == null) return;

    switch (refType) {
      case 'order':
        context.go('/orders/$refId');
        break;
      case 'consultation':
        context.go('/experts/consultation/$refId');
        break;
      case 'transport_job':
        context.go('/transport/$refId');
        break;
      case 'knowledge_post':
        context.go('/knowledge/post/$refId');
        break;
      default:
        break;
    }
  }

  // Group by Today / Earlier
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final today = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final n in _notifications) {
      final created =
          DateTime.parse(n['created_at'] as String);
      if (now.difference(created).inHours < 24) {
        today.add(n);
      } else {
        earlier.add(n);
      }
    }
    return {'Today': today, 'Earlier': earlier};
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((n) => n['is_read'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _Empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildList(),
                ),
    );
  }

  Widget _buildList() {
    final groups = _grouped();
    final items = <Widget>[];

    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(entry.key,
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary)),
        ),
      );
      for (final n in entry.value) {
        items.add(_NotificationTile(
          notification: n,
          onTap: () => _handleTap(n),
        ));
      }
    }

    return ListView(
      children: items,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile(
      {required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    final type = notification['type'] as String? ?? 'system';
    final config = _typeConfig(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRead ? AppColors.white : AppColors.primarySurface,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: config.$2.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(config.$1, color: config.$2, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] as String? ?? '',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification['body'] as String? ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(DateTime.parse(
                        notification['created_at'] as String)),
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _typeConfig(String type) {
    switch (type) {
      case 'order_update':
        return (Icons.shopping_bag_outlined, AppColors.primary);
      case 'consultation_request':
      case 'consultation_message':
        return (Icons.support_agent_outlined, AppColors.expertRole);
      case 'transport_bid':
      case 'transport_update':
        return (Icons.local_shipping_outlined, AppColors.driverRole);
      case 'payment':
        return (Icons.payments_outlined, AppColors.success);
      case 'verification':
        return (Icons.verified_outlined, AppColors.info);
      case 'knowledge_post':
        return (Icons.article_outlined, AppColors.secondary);
      case 'review':
        return (Icons.star_outline, AppColors.warning);
      default:
        return (Icons.notifications_outlined, AppColors.primary);
    }
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you about orders, consultations, and more.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
