import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/marketplace_models.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _buyingOrders = [];
  List<OrderModel> _sellingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId!;
    try {
      final buying = await SupabaseService.client
          .from('orders')
          .select('*, order_items(*), escrow_records(*)')
          .eq('buyer_id', uid)
          .order('created_at', ascending: false);

      final selling = await SupabaseService.client
          .from('orders')
          .select('*, order_items(*), escrow_records(*)')
          .eq('seller_id', uid)
          .order('created_at', ascending: false);

      setState(() {
        _buyingOrders =
            (buying as List).map((e) => OrderModel.fromJson(e)).toList();
        _sellingOrders =
            (selling as List).map((e) => OrderModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Buying (${_buyingOrders.length})'),
            Tab(text: 'Selling (${_sellingOrders.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(orders: _buyingOrders, isBuyer: true),
                _OrderList(orders: _sellingOrders, isBuyer: false),
              ],
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isBuyer;

  const _OrderList({required this.orders, required this.isBuyer});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isBuyer ? '🛒' : '📦',
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              isBuyer ? 'No purchases yet' : 'No sales yet',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isBuyer
                  ? 'Browse the marketplace to find fresh produce.'
                  : 'Create a listing to start selling.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _OrderCard(
          order: orders[i],
          isBuyer: isBuyer,
          onTap: () => context.go('/orders/${orders[i].id}'),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isBuyer;
  final VoidCallback onTap;

  const _OrderCard(
      {required this.order, required this.isBuyer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(order.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id.substring(0, 8).toUpperCase()}',
                  style: AppTextStyles.titleSmall,
                ),
                _StatusBadge(label: statusConfig.$1, color: statusConfig.$2),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.items.length} item${order.items.length != 1 ? 's' : ''}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeago.format(order.createdAt),
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  '${AppConstants.currencySymbol}${order.totalGhs.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            if (order.escrow != null && order.escrow!.isHeld) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_outlined,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      'Escrow held — auto-releases ${timeago.format(order.escrow!.autoReleaseAt, allowFromNow: true)}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, Color) _statusConfig(String status) {
    switch (status) {
      case 'pending_payment':
        return ('Pending Payment', AppColors.warning);
      case 'paid':
        return ('Paid', AppColors.info);
      case 'processing':
        return ('Processing', AppColors.info);
      case 'shipped':
        return ('Shipped', AppColors.primary);
      case 'delivered':
        return ('Delivered', AppColors.secondary);
      case 'completed':
        return ('Completed', AppColors.success);
      case 'disputed':
        return ('Disputed', AppColors.error);
      case 'refunded':
        return ('Refunded', AppColors.textSecondary);
      case 'cancelled':
        return ('Cancelled', AppColors.textTertiary);
      default:
        return (status, AppColors.textSecondary);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style:
              AppTextStyles.labelSmall.copyWith(color: color, fontSize: 11)),
    );
  }
}
