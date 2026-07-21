import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class SetupExpertProfileScreen extends ConsumerStatefulWidget {
  const SetupExpertProfileScreen({super.key});

  @override
  ConsumerState<SetupExpertProfileScreen> createState() =>
      _SetupExpertProfileScreenState();
}

class _SetupExpertProfileScreenState
    extends ConsumerState<SetupExpertProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _institutionController = TextEditingController();
  final _yearsController = TextEditingController();
  final _priceController = TextEditingController();
  final _bioController = TextEditingController();
  final _specializationInput = TextEditingController();
  final _qualificationInput = TextEditingController();

  String _label = 'expert';
  final List<String> _specializations = [];
  final List<String> _qualifications = [];
  final List<String> _availableDays = [];
  bool _isAvailable = true;
  bool _isLoading = false;

  static const _labels = [
    ('expert', '🎓 Expert'),
    ('lecturer', '📚 Lecturer'),
    ('consultant', '💼 Consultant'),
  ];

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void dispose() {
    _institutionController.dispose();
    _yearsController.dispose();
    _priceController.dispose();
    _bioController.dispose();
    _specializationInput.dispose();
    _qualificationInput.dispose();
    super.dispose();
  }

  void _addSpecialization() {
    final val = _specializationInput.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _specializations.add(val);
      _specializationInput.clear();
    });
  }

  void _addQualification() {
    final val = _qualificationInput.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _qualifications.add(val);
      _qualificationInput.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_specializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one specialization')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId!;

      // Update bio on users table
      await SupabaseService.client.from('users').update({
        'bio': _bioController.text.trim(),
      }).eq('id', uid);

      // Upsert expert profile
      await SupabaseService.client.from('expert_profiles').upsert({
        'user_id': uid,
        'label': _label,
        'specializations': _specializations,
        'qualifications': _qualifications,
        'institution': _institutionController.text.trim(),
        'years_experience': int.tryParse(_yearsController.text.trim()),
        'session_price_ghs': double.tryParse(_priceController.text.trim()) ?? 0,
        'available_days': _availableDays,
        'is_available': _isAvailable,
        'verification_status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Expert profile saved!'),
          backgroundColor: AppColors.success));
      context.go(AppConstants.routeProfile);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Expert Profile Setup'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🎓', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set up your expert profile',
                              style: AppTextStyles.titleMedium),
                          Text(
                              'Complete this to start accepting paid consultations.',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Label
              Text('Your Role', style: AppTextStyles.titleLarge),
              const SizedBox(height: 10),
              Row(
                children: _labels.map((l) {
                  final isSelected = _label == l.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _label = l.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Text(
                          l.$2,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Short Bio',
                hint:
                    'Tell people about your background and expertise...',
                controller: _bioController,
                maxLines: 3,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Bio is required' : null,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Institution / Organisation',
                hint: 'e.g. University of Ghana, CSIR',
                controller: _institutionController,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Years of Experience',
                hint: '5',
                controller: _yearsController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Session Price (₵)',
                hint: '50.00',
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('₵',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16))),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Specializations
              Text('Specializations', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('e.g. Crop Science, Soil Management, Agribusiness',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _specializationInput,
                      decoration: InputDecoration(
                        hintText: 'Add specialization...',
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _addSpecialization(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addSpecialization,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              if (_specializations.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _specializations
                      .map((s) => Chip(
                            label: Text(s),
                            onDeleted: () =>
                                setState(() => _specializations.remove(s)),
                            backgroundColor: AppColors.primarySurface,
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),

              // Qualifications
              Text('Qualifications', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('e.g. BSc Agriculture, PhD Plant Science',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qualificationInput,
                      decoration: InputDecoration(
                        hintText: 'Add qualification...',
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _addQualification(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addQualification,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              if (_qualifications.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _qualifications
                      .map((q) => Chip(
                            label: Text(q),
                            onDeleted: () =>
                                setState(() => _qualifications.remove(q)),
                            backgroundColor: AppColors.secondarySurface,
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),

              // Available days
              Text('Available Days', style: AppTextStyles.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map((day) {
                  final isSelected = _availableDays.contains(day);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _availableDays.remove(day);
                      } else {
                        _availableDays.add(day);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
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
                      child: Text(
                        day.substring(0, 3),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Availability toggle
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isAvailable
                      ? AppColors.success.withOpacity(0.08)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isAvailable
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available for Consultations',
                              style: AppTextStyles.titleSmall),
                          Text(
                            _isAvailable
                                ? 'You are visible and accepting bookings'
                                : 'You are hidden from the experts list',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAvailable,
                      onChanged: (v) =>
                          setState(() => _isAvailable = v),
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              AppButton(
                label: 'Save Expert Profile',
                onPressed: _isLoading ? null : _save,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
