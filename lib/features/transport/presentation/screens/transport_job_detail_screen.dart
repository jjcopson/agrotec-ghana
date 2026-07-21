import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/transport_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_avatar.dart';

class TransportJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  const TransportJobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<TransportJobDetailScreen> createState() =>
      _TransportJobDetailScreenState();
}

class _TransportJobDetailScreenState
    extends ConsumerState<TransportJobDetailScreen> {
  TransportJobModel? _job;
  List<TransportBidModel> _bids = [];
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobData = await SupabaseService.client
          .from('transport_jobs')
          .select('*, poster:poster_id(full_name, avatar_url), driver:assigned_driver_id(full_name, avatar_url)')
          .eq('id', widget.jobId)
          .single();

      final bidsData = await SupabaseService.client
          .from('transport_bids')
          .select('*, users(full_name, avatar_url), driver_profiles(rating, total_trips, vehicle_type)')
          .eq('job_id', widget.jobId)
          .order('bid_amount_ghs', ascending: true);

      setState(() {
        _job = TransportJobModel.fromJson(jobData);
        _bids = (bidsData as List)
            .map((e) => TransportBidModel.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptBid(TransportBidModel bid) async {
    setState(() => _isActing = true);
    try {
      await SupabaseService.client.from('transport_jobs').update({
        'status': 'assigned',
        'assigned_driver_id': bid.driverId,
        'agreed_price_ghs': bid.bidAmountGhs,
        'assigned_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.jobId);

      await SupabaseService.client.from('transport_bids').update({
        'status': 'accepted',
      }).eq('id', bid.id);

      // Reject other bids
      await SupabaseService.client.from('transport_bids').update({
        'status': 'rejected',
      }).eq('job_id', widget.jobId).neq('id', bid.id);

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bid accepted! Driver has been notified.'),
            backgroundColor: AppColors.success));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _placeBid() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BidSheet(job: _job!),
    );
    if (result == null) return;

    setState(() => _isActing = true);
    try {
      await SupabaseService.client.from('transport_bids').upsert({
        'job_id': widget.jobId,
        'driver_id': SupabaseService.currentUserId,
        'bid_amount_ghs': result['amount'],
        'message': result['message'],
        'estimated_days': result['days'],
        'status': 'pending',
      });

      // Update job status to bidding
      await SupabaseService.client.from('transport_jobs').update({
        'status': 'bidding',
      }).eq('id', widget.jobId).eq('status', 'open');

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bid placed successfully!'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_job == null) {
      return const Scaffold(
          body: Center(child: Text('Job not found')));
    }

    final j = _job!;
    final uid = SupabaseService.currentUserId;
    final isPoster = j.posterId == uid;
    final hasMyBid = _bids.any((b) => b.driverId == uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Transport Job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(j.title,
                              style: AppTextStyles.headlineSmall)),
                      _StatusPill(j.status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Route
                  _RouteRow(
                    from: j.pickupAddress,
                    fromRegion: j.pickupRegion,
                    to: j.deliveryAddress,
                    toRegion: j.deliveryRegion,
                  ),
                  const SizedBox(height: 16),

                  // Details grid
                  _DetailGrid([
                    ('Cargo', j.cargoType),
                    if (j.cargoWeightKg != null)
                      ('Weight', '${j.cargoWeightKg!.toStringAsFixed(0)} kg'),
                    ('Pickup Date',
                        DateFormat('MMM d, y').format(j.pickupDate)),
                    if (j.budgetGhs != null)
                      ('Budget', '₵${j.budgetGhs!.toStringAsFixed(2)}'),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description
            if (j.description != null && j.description!.isNotEmpty) ...[
              Text('Details', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(j.description!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary, height: 1.6)),
              const SizedBox(height: 20),
            ],

            // Posted by
            Text('Posted by', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                AppAvatar(
                    imageUrl: j.posterAvatar,
                    name: j.posterName,
                    size: 40),
                const SizedBox(width: 12),
                Text(j.posterName ?? 'Poster',
                    style: AppTextStyles.titleMedium),
              ],
            ),
            const SizedBox(height: 24),

            // Bids section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bids (${_bids.length})',
                    style: AppTextStyles.titleLarge),
                if (j.isAssigned && j.driverName != null)
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(j.driverName!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.success)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_bids.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Text('🚛', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 8),
                    Text('No bids yet', textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ..._bids.map((bid) => _BidCard(
                    bid: bid,
                    isPoster: isPoster,
                    isAccepted: bid.isAccepted,
                    onAccept: j.isOpen
                        ? () => _acceptBid(bid)
                        : null,
                  )),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: !isPoster && j.isOpen && !hasMyBid
          ? Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: AppButton(
                label: 'Place a Bid',
                onPressed: _isActing ? null : _placeBid,
                isLoading: _isActing,
              ),
            )
          : null,
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String from;
  final String fromRegion;
  final String to;
  final String toRegion;

  const _RouteRow(
      {required this.from,
      required this.fromRegion,
      required this.to,
      required this.toRegion});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.success, shape: BoxShape.circle)),
            Container(
                width: 2, height: 32, color: AppColors.border),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(from,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(fromRegion,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Text(to,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(toRegion,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final List<(String, String)> items;
  const _DetailGrid(this.items);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$1,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textTertiary)),
                Text(item.$2, style: AppTextStyles.titleSmall),
              ],
            ),
          )).toList(),
    );
  }
}

class _BidCard extends StatelessWidget {
  final TransportBidModel bid;
  final bool isPoster;
  final bool isAccepted;
  final VoidCallback? onAccept;

  const _BidCard(
      {required this.bid,
      required this.isPoster,
      required this.isAccepted,
      this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAccepted
            ? AppColors.success.withOpacity(0.06)
            : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isAccepted
                ? AppColors.success.withOpacity(0.4)
                : AppColors.border,
            width: isAccepted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                  imageUrl: bid.driverAvatar,
                  name: bid.driverName,
                  size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bid.driverName ?? 'Driver',
                        style: AppTextStyles.titleSmall),
                    if (bid.vehicleType != null)
                      Text(bid.vehicleType!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₵${bid.bidAmountGhs.toStringAsFixed(2)}',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.primary),
                  ),
                  if (bid.estimatedDays != null)
                    Text('${bid.estimatedDays}d',
                        style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
          if (bid.driverRating != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, size: 13, color: AppColors.warning),
                const SizedBox(width: 3),
                Text(bid.driverRating!.toStringAsFixed(1),
                    style: AppTextStyles.labelSmall),
                const SizedBox(width: 8),
                Text('${bid.driverTotalTrips ?? 0} trips',
                    style: AppTextStyles.labelSmall),
              ],
            ),
          ],
          if (bid.message != null && bid.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bid.message!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
          if (isPoster && !isAccepted && onAccept != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAccept,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Accept this bid'),
              ),
            ),
          ],
          if (isAccepted) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text('Bid Accepted',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.success)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget _StatusPill(String status) {
  final config = switch (status) {
    'open' => ('Open', AppColors.success),
    'bidding' => ('Bidding', AppColors.primary),
    'assigned' => ('Assigned', AppColors.info),
    'in_transit' => ('In Transit', AppColors.warning),
    'delivered' => ('Delivered', AppColors.secondary),
    'completed' => ('Completed', AppColors.success),
    _ => (status, AppColors.textSecondary),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: config.$2.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(config.$1,
        style: AppTextStyles.labelSmall.copyWith(color: config.$2)),
  );
}

class _BidSheet extends StatefulWidget {
  final TransportJobModel job;
  const _BidSheet({required this.job});

  @override
  State<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<_BidSheet> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  final _daysController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Place a Bid', style: AppTextStyles.headlineSmall),
            if (widget.job.budgetGhs != null)
              Text(
                'Posted budget: ₵${widget.job.budgetGhs!.toStringAsFixed(2)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Your Bid Amount (₵)',
                prefixText: '₵ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Estimated Days',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message to poster (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Submit Bid',
              onPressed: () {
                final amount =
                    double.tryParse(_amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Enter a valid bid amount')));
                  return;
                }
                Navigator.pop(context, {
                  'amount': amount,
                  'message': _messageController.text.trim(),
                  'days': int.tryParse(_daysController.text),
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
