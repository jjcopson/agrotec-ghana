import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/auth_provider.dart';

class _RoleOption {
  final String value;
  final String title;
  final String description;
  final String emoji;
  final Color color;

  const _RoleOption({
    required this.value,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
  });
}

const _roles = [
  _RoleOption(
    value: 'farmer',
    title: 'Farmer',
    description: 'Grow and sell agricultural produce',
    emoji: '🌾',
    color: AppColors.farmerRole,
  ),
  _RoleOption(
    value: 'processing_industry',
    title: 'Processing Industry',
    description: 'Process and package agricultural goods',
    emoji: '🏭',
    color: AppColors.businessRole,
  ),
  _RoleOption(
    value: 'truck_driver',
    title: 'Truck Driver',
    description: 'Transport goods across Ghana',
    emoji: '🚛',
    color: AppColors.driverRole,
  ),
  _RoleOption(
    value: 'wholesaler',
    title: 'Wholesaler',
    description: 'Buy and distribute in bulk',
    emoji: '📦',
    color: AppColors.businessRole,
  ),
  _RoleOption(
    value: 'retailer',
    title: 'Retailer',
    description: 'Sell produce directly to customers',
    emoji: '🏪',
    color: AppColors.businessRole,
  ),
  _RoleOption(
    value: 'expert',
    title: 'Expert / Lecturer / Consultant',
    description: 'Share knowledge and earn from consultations',
    emoji: '🎓',
    color: AppColors.expertRole,
  ),
  _RoleOption(
    value: 'enthusiast',
    title: 'Agriculture Enthusiast',
    description: 'Learn and explore the agricultural world',
    emoji: '🌱',
    color: AppColors.enthusiastRole,
  ),
  _RoleOption(
    value: 'customer',
    title: 'Customer',
    description: 'Buy fresh produce and agricultural products',
    emoji: '🛒',
    color: AppColors.customerRole,
  ),
];

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  final Set<String> _selectedRoles = {'customer'};
  bool _isLoading = false;

  Future<void> _continue() async {
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one role')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        context.go(AppConstants.routeLogin);
        return;
      }

      final rolesList = _selectedRoles.toList();
      final primaryRole = rolesList.first;

      // Save roles directly to the users table
      await SupabaseService.client.from('users').update({
        'roles': rolesList,
        'active_role': primaryRole,
      }).eq('id', userId);

      await ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;

      // If expert or business role selected, go to verification
      final needsVerification = _selectedRoles.any((r) =>
          r == 'expert' ||
          r == 'processing_industry' ||
          r == 'wholesaler' ||
          r == 'truck_driver');

      if (needsVerification) {
        context.go(AppConstants.routeVerification);
      } else {
        context.go(AppConstants.routeHome);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving roles: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What describes\nyou best?',
                    style: AppTextStyles.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select all roles that apply. You can always add more later.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Selection count indicator
                  if (_selectedRoles.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedRoles.length} selected',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Roles list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final role = _roles[index];
                  final isSelected = _selectedRoles.contains(role.value);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedRoles.length > 1) {
                            _selectedRoles.remove(role.value);
                          }
                        } else {
                          _selectedRoles.add(role.value);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? role.color.withOpacity(0.08)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSelected ? role.color : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Emoji icon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: role.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                role.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Title + description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  role.title,
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  role.description,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Check circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? role.color
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? role.color
                                    : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: AppButton(
                label: _selectedRoles.length == 1
                    ? 'Continue with ${_selectedRoles.length} role'
                    : 'Continue with ${_selectedRoles.length} roles',
                onPressed: _isLoading ? null : _continue,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
