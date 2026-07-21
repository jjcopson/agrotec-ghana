import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/consultation_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_avatar.dart';

class ExpertProfileScreen extends ConsumerStatefulWidget {
  final String expertId;
  const ExpertProfileScreen({super.key, required this.expertId});

  @override
  ConsumerState<ExpertProfileScreen> createState() =>
      _ExpertProfileScreenState();
}

class _ExpertProfileScreenState extends ConsumerState<ExpertProfileScreen> {
  ExpertProfileModel? _expert;
  bool _isLoading = true;
  bool _isBooking = false;
  final _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('expert_profiles')
          .select('*, users(full_name, avatar_url, bio, region)')
          .eq('user_id', widget.expertId)
          .single();
      setState(() {
        _expert = ExpertProfileModel.fromJson(data);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bookConsultation() async {
    if (_expert == null) return;
    final topic = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(expert: _expert!),
    );
    if (topic == null || topic.isEmpty) return;

    setState(() => _isBooking = true);
    try {
      final result = await SupabaseService.client
          .from('consultations')
          .insert({
            'client_id': SupabaseService.currentUserId,
            'expert_id': _expert!.userId,
            'expert_profile_id': _expert!.id,
            'status': 'requested',
            'topic': topic,
            'session_price_ghs': _expert!.sessionPriceGhs,
            'platform_fee_ghs':
                _expert!.sessionPriceGhs * 0.05,
            'expert_earnings_ghs':
                _expert!.sessionPriceGhs * 0.95,
            'free_start_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      if (!mounted) return;
      context.go('/experts/consultation/${result['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_expert == null) {
      return const Scaffold(
          body: Center(child: Text('Expert not found')));
    }

    final e = _expert!;
    final isOwn = e.userId == SupabaseService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppAvatar(
                          imageUrl: e.avatarUrl,
                          name: e.fullName,
                          size: 72,
                          showVerified: e.isVerified,
                        ),
                        const SizedBox(height: 12),
                        Text(e.fullName ?? 'Expert',
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: Colors.white)),
                        Text(e.displayLabel,
                            style: AppTextStyles.bodyMedium
                                .copyWith(
                                    color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatBox(
                          '⭐ ${e.rating.toStringAsFixed(1)}', 'Rating'),
                      const SizedBox(width: 12),
                      _StatBox('${e.totalConsultations}', 'Sessions'),
                      const SizedBox(width: 12),
                      _StatBox(
                          e.yearsExperience != null
                              ? '${e.yearsExperience}y'
                              : 'N/A',
                          'Experience'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Session price
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Session Fee',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(
                                          color: AppColors.textSecondary)),
                              Text(
                                e.sessionPriceGhs == 0
                                    ? 'Free'
                                    : '₵${e.sessionPriceGhs.toStringAsFixed(2)} per session',
                                style: AppTextStyles.titleMedium
                                    .copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('10 min free',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.success)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  if (e.bio != null && e.bio!.isNotEmpty) ...[
                    Text('About', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Text(e.bio!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary,
                                height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Specializations
                  Text('Specializations', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: e.specializations
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.border),
                              ),
                              child: Text(s,
                                  style: AppTextStyles.labelMedium
                                      .copyWith(
                                          color: AppColors.primary)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Qualifications
                  if (e.qualifications != null &&
                      e.qualifications!.isNotEmpty) ...[
                    Text('Qualifications', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 10),
                    ...e.qualifications!.map((q) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.school_outlined,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(q, style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Institution
                  if (e.institution != null) ...[
                    Text('Institution', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(e.institution!,
                            style: AppTextStyles.bodyMedium
                                .copyWith(
                                    color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Availability
                  if (e.availableDays != null &&
                      e.availableDays!.isNotEmpty) ...[
                    Text('Available Days', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: e.availableDays!
                          .map((d) => Chip(
                                label: Text(d),
                                backgroundColor:
                                    AppColors.secondarySurface,
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isOwn
          ? null
          : Container(
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
                label: e.isAvailable
                    ? 'Start Consultation'
                    : 'Expert Unavailable',
                onPressed:
                    e.isAvailable && !_isBooking ? _bookConsultation : null,
                isLoading: _isBooking,
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleLarge),
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  final ExpertProfileModel expert;
  const _BookingSheet({required this.expert});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _topicController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
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
          Text('Start Consultation', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'With ${widget.expert.fullName ?? 'Expert'} · First 10 min free',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _topicController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'What would you like to discuss? e.g. "Best fertilizer for maize in dry season"',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              labelText: 'Consultation Topic',
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Start Now',
            onPressed: () {
              final topic = _topicController.text.trim();
              if (topic.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enter a topic')));
                return;
              }
              Navigator.pop(context, topic);
            },
          ),
        ],
      ),
    );
  }
}
