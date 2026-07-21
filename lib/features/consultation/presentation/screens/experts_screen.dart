import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/consultation_model.dart';
import '../../../../shared/widgets/app_avatar.dart';

class ExpertsScreen extends ConsumerStatefulWidget {
  const ExpertsScreen({super.key});

  @override
  ConsumerState<ExpertsScreen> createState() => _ExpertsScreenState();
}

class _ExpertsScreenState extends ConsumerState<ExpertsScreen> {
  List<ExpertProfileModel> _experts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedLabel = 'all';
  final _searchController = TextEditingController();

  static const _labels = [
    ('all', 'All'),
    ('expert', 'Experts'),
    ('lecturer', 'Lecturers'),
    ('consultant', 'Consultants'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      dynamic query = SupabaseService.client
          .from('expert_profiles')
          .select('*, users(full_name, avatar_url, bio, region)')
          .eq('verification_status', 'approved');

      if (_selectedLabel != 'all') {
        query = (query as dynamic).eq('label', _selectedLabel);
      }

      final data = await (query as dynamic)
          .order('rating', ascending: false);
      var experts = (data as List)
          .map((e) => ExpertProfileModel.fromJson(e))
          .toList();

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        experts = experts
            .where((e) =>
                (e.fullName?.toLowerCase().contains(q) ?? false) ||
                e.specializations
                    .any((s) => s.toLowerCase().contains(q)))
            .toList();
      }

      setState(() {
        _experts = experts;
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
        title: const Text('Expert Consultations'),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Search by name or specialization...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Label filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final l = _labels[i];
                final isSelected = _selectedLabel == l.$1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLabel = l.$1;
                      _isLoading = true;
                    });
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Text(l.$2,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                );
              },
            ),
          ),

          // Free banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'First 10 minutes or 10 messages are FREE with every expert.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),

          // Expert list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _experts.isEmpty
                    ? _Empty(onClear: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedLabel = 'all';
                        });
                        _load();
                      })
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _experts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _ExpertCard(
                            expert: _experts[i],
                            onTap: () => context
                                .go('/experts/${_experts[i].userId}'),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  final ExpertProfileModel expert;
  final VoidCallback onTap;

  const _ExpertCard({required this.expert, required this.onTap});

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppAvatar(
                  imageUrl: expert.avatarUrl,
                  name: expert.fullName,
                  size: 56,
                  showVerified: true,
                ),
                if (expert.isAvailable)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(expert.fullName ?? 'Expert',
                            style: AppTextStyles.titleMedium),
                      ),
                      _LabelBadge(label: expert.label),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (expert.institution != null)
                    Text(expert.institution!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: expert.specializations
                        .take(3)
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(s,
                                  style:
                                      AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.primary,
                                          fontSize: 10)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Text(expert.rating.toStringAsFixed(1),
                          style: AppTextStyles.labelMedium),
                      const SizedBox(width: 8),
                      Text('•',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary)),
                      const SizedBox(width: 8),
                      Text(
                        '${expert.totalConsultations} sessions',
                        style: AppTextStyles.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        expert.sessionPriceGhs == 0
                            ? 'Free'
                            : '₵${expert.sessionPriceGhs.toStringAsFixed(0)}/session',
                        style: AppTextStyles.titleSmall
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelBadge extends StatelessWidget {
  final String label;
  const _LabelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'expert': AppColors.expertRole,
      'lecturer': Color(0xFF7C3AED),
      'consultant': Color(0xFF0369A1),
    };
    final color = colors[label] ?? AppColors.expertRole;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onClear;
  const _Empty({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No experts found', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text('Try a different search or label filter.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
