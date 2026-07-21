import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../shared/models/marketplace_models.dart';
import '../../../../shared/widgets/app_button.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  OrderModel? _order;
  bool _isLoading = true;
  bool _isActing = false;
  Timer? _countdownTimer;
  Duration _escrowCountdown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('orders')
          .select('*, order_items(*), escrow_records(*)')
          .eq('id', widget.orderId)
          .single();
      setState(() {
        _order = OrderModel.fromJson(data);
        _isLoading = false;
      });
      if (_order?.escrow?.isHeld == true) {
        _startCountdown();
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _order!.escrow!.timeUntilAutoRelease;
      setState(() => _escrowCountdown =
          remaining.isNegative ? Duration.zero : remaining);
    });
  }

  Future<void> _confirmDelivery() async {
    setState(() => _isActing = true);
    try {
      await PaymentService.releaseEscrow(
        orderId: widget.orderId,
        triggeredBy: 'buyer_confirm',
      );
      await SupabaseService.client
          .from('orders')
          .update({'status': 'completed', 'completed_at': DateTime.now().toIso8601String()})
          .eq('id', widget.orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Delivery confirmed. Payment released to seller.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _raiseDispute() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DisputeDialog(),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isActing = true);
    try {
      await SupabaseService.client.from('orders').update({
        'status': 'disputed',
        'dispute_reason': reason,
        'disputed_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Dispute raised. Our team will review within 24 hours.')));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }

    final o = _order!;
    final isBuyer = o.buyerId == SupabaseService.currentUserId;
    final steps = _buildSteps(o.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text('Order #${o.id.substring(0, 8).toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status timeline
            _StatusTimeline(steps: steps),
            const SizedBox(height: 24),

            // Escrow card
            if (o.escrow != null) ...[
              _EscrowCard(
                escrow: o.escrow!,
                countdown: _escrowCountdown,
              ),
              const SizedBox(height: 20),
            ],

            // Order items
            Text('Items', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            ...o.items.map((item) => _ItemRow(item: item)),
            const SizedBox(height: 20),

            // Price breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _PriceRow('Subtotal',
                      '${AppConstants.currencySymbol}${o.subtotalGhs.toStringAsFixed(2)}'),
                  if (o.deliveryFeeGhs > 0)
                    _PriceRow('Delivery',
                        '${AppConstants.currencySymbol}${o.deliveryFeeGhs.toStringAsFixed(2)}'),
                  _PriceRow('Platform fee',
                      '${AppConstants.currencySymbol}${o.platformFeeGhs.toStringAsFixed(2)}'),
                  const Divider(height: 16),
                  _PriceRow(
                    'Total',
                    '${AppConstants.currencySymbol}${o.totalGhs.toStringAsFixed(2)}',
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Delivery address
            if (o.deliveryAddress != null &&
                o.deliveryAddress!.isNotEmpty) ...[
              Text('Delivery Address', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(o.deliveryAddress!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Order date
            Text(
              'Ordered ${timeago.format(o.createdAt)}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 32),

            // Action buttons (buyer only)
            if (isBuyer && o.canConfirmDelivery) ...[
              AppButton(
                label: 'Confirm Delivery & Release Payment',
                onPressed: _isActing ? null : _confirmDelivery,
                isLoading: _isActing,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Raise a Dispute',
                variant: AppButtonVariant.outline,
                onPressed: _isActing ? null : _raiseDispute,
              ),
            ],

            if (o.isCompleted) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Order completed. Payment has been released to the seller.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.success),
                      ),
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

  List<_StepData> _buildSteps(String status) {
    final all = [
      _StepData('Order Placed', Icons.shopping_cart_outlined),
      _StepData('Payment Confirmed', Icons.payment_outlined),
      _StepData('Processing', Icons.pending_outlined),
      _StepData('Shipped', Icons.local_shipping_outlined),
      _StepData('Delivered', Icons.home_outlined),
      _StepData('Completed', Icons.check_circle_outline),
    ];

    const statusIndex = {
      'pending_payment': 0,
      'paid': 1,
      'processing': 2,
      'shipped': 3,
      'delivered': 4,
      'completed': 5,
    };

    final current = statusIndex[status] ?? 0;
    for (int i = 0; i < all.length; i++) {
      all[i] = _StepData(all[i].label, all[i].icon,
          done: i < current, active: i == current);
    }
    return all;
  }
}

class _StepData {
  final String label;
  final IconData icon;
  final bool done;
  final bool active;

  _StepData(this.label, this.icon, {this.done = false, this.active = false});
}

class _StatusTimeline extends StatelessWidget {
  final List<_StepData> steps;
  const _StatusTimeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: steps.asMap().entries.map((e) {
          final s = e.value;
          final isLast = e.key == steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.done
                          ? AppColors.primary
                          : s.active
                              ? AppColors.primarySurface
                              : AppColors.border,
                    ),
                    child: Icon(s.icon,
                        size: 16,
                        color: s.done
                            ? Colors.white
                            : s.active
                                ? AppColors.primary
                                : AppColors.textTertiary),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 24,
                      color: s.done ? AppColors.primary : AppColors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.label,
                    style: AppTextStyles.titleSmall.copyWith(
                        color: s.done || s.active
                            ? AppColors.textPrimary
                            : AppColors.textTertiary)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _EscrowCard extends StatelessWidget {
  final EscrowModel escrow;
  final Duration countdown;

  const _EscrowCard({required this.escrow, required this.countdown});

  @override
  Widget build(BuildContext context) {
    final days = countdown.inDays;
    final hours = countdown.inHours % 24;
    final mins = countdown.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: escrow.isReleased
            ? AppColors.success.withOpacity(0.08)
            : AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: escrow.isReleased
                ? AppColors.success.withOpacity(0.3)
                : AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                escrow.isReleased
                    ? Icons.check_circle_outline
                    : Icons.lock_clock_outlined,
                color: escrow.isReleased
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Text(
                escrow.isReleased ? 'Escrow Released' : 'Funds in Escrow',
                style: AppTextStyles.titleSmall.copyWith(
                    color: escrow.isReleased
                        ? AppColors.success
                        : AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            escrow.isReleased
                ? 'Payment of ${AppConstants.currencySymbol}${escrow.amountGhs.toStringAsFixed(2)} has been released to the seller.'
                : '${AppConstants.currencySymbol}${escrow.amountGhs.toStringAsFixed(2)} is securely held. Auto-releases in: ${days}d ${hours}h ${mins}m',
            style: AppTextStyles.bodySmall.copyWith(
                color: escrow.isReleased
                    ? AppColors.success
                    : AppColors.warning),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItemModel item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.snapshotImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.snapshotImage!,
                        fit: BoxFit.cover))
                : const Center(
                    child: Text('📦', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.snapshotTitle ?? 'Item',
                    style: AppTextStyles.titleSmall),
                Text('Qty: ${item.quantity.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            '${AppConstants.currencySymbol}${item.totalPriceGhs.toStringAsFixed(2)}',
            style:
                AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
          Text(value,
              style: bold
                  ? AppTextStyles.titleSmall
                      .copyWith(color: AppColors.primary)
                  : AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Raise Dispute'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Please describe the issue. Our team will review within 24 hours.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe the problem...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero),
          child: const Text('Submit Dispute'),
        ),
      ],
    );
  }
}
