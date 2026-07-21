import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/transport_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class TransportScreen extends ConsumerStatefulWidget {
  const TransportScreen({super.key});

  @override
  ConsumerState<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends ConsumerState<TransportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TransportJobModel> _openJobs = [];
  List<TransportJobModel> _myJobs = [];
  bool _isLoading = true;
  String _filterRegion = '';

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
      dynamic q = SupabaseService.client
          .from('transport_jobs')
          .select('*, poster:poster_id(full_name, avatar_url)')
          .inFilter('status', ['open', 'bidding']);

      if (_filterRegion.isNotEmpty) {
        q = (q as dynamic).eq('pickup_region', _filterRegion);
      }

      final open = await (q as dynamic)
          .order('created_at', ascending: false);
      final mine = await SupabaseService.client
          .from('transport_jobs')
          .select('*, poster:poster_id(full_name, avatar_url), driver:assigned_driver_id(full_name, avatar_url)')
          .eq('poster_id', uid)
          .order('created_at', ascending: false);

      setState(() {
        _openJobs =
            (open as List).map((e) => TransportJobModel.fromJson(e)).toList();
        _myJobs =
            (mine as List).map((e) => TransportJobModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final isDriver = user?.isDriver ?? false;
    final canPost = user != null && !isDriver;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Transport'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () => _showRegionFilter(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: isDriver ? 'Available Jobs' : 'Open Jobs'),
            Tab(text: 'My Jobs (${_myJobs.length})'),
          ],
        ),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/transport/create'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Post Job',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: Colors.white)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _JobList(
                  jobs: _openJobs,
                  emptyMessage: 'No open jobs in your area',
                  onTap: (id) => context.go('/transport/$id'),
                ),
                _JobList(
                  jobs: _myJobs,
                  emptyMessage: 'You haven\'t posted any jobs yet',
                  onTap: (id) => context.go('/transport/$id'),
                ),
              ],
            ),
    );
  }

  void _showRegionFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text('Filter by Pickup Region',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('All Regions'),
            leading: Radio<String>(
              value: '',
              groupValue: _filterRegion,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() => _filterRegion = v!);
                Navigator.pop(context);
                _load();
              },
            ),
          ),
          ...AppConstants.ghanaRegions.map((r) => ListTile(
                title: Text(r),
                leading: Radio<String>(
                  value: r,
                  groupValue: _filterRegion,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _filterRegion = v!);
                    Navigator.pop(context);
                    _load();
                  },
                ),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  final List<TransportJobModel> jobs;
  final String emptyMessage;
  final void Function(String) onTap;

  const _JobList(
      {required this.jobs,
      required this.emptyMessage,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚛', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(emptyMessage, style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) =>
            _JobCard(job: jobs[i], onTap: () => onTap(jobs[i].id)),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final TransportJobModel job;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
              children: [
                Expanded(
                  child: Text(job.title, style: AppTextStyles.titleMedium),
                ),
                _StatusPill(status: job.status),
              ],
            ),
            const SizedBox(height: 10),

            // Route
            Row(
              children: [
                const Icon(Icons.trip_origin,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${job.pickupRegion} — ${job.deliveryRegion}',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Cargo + date
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(job.cargoType, style: AppTextStyles.bodySmall),
                if (job.cargoWeightKg != null) ...[
                  const SizedBox(width: 4),
                  Text('· ${job.cargoWeightKg!.toStringAsFixed(0)} kg',
                      style: AppTextStyles.bodySmall),
                ],
                const Spacer(),
                Text(timeago.format(job.createdAt),
                    style: AppTextStyles.bodySmall),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                if (job.budgetGhs != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Budget: ₵${job.budgetGhs!.toStringAsFixed(0)}',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                const Spacer(),
                const Icon(Icons.gavel_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${job.bidsCount} bids',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
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
}
