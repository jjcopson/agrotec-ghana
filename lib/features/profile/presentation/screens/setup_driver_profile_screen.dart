import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class SetupDriverProfileScreen extends ConsumerStatefulWidget {
  const SetupDriverProfileScreen({super.key});

  @override
  ConsumerState<SetupDriverProfileScreen> createState() =>
      _SetupDriverProfileScreenState();
}

class _SetupDriverProfileScreenState
    extends ConsumerState<SetupDriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _capacityController = TextEditingController();

  String _vehicleType = 'truck';
  String _licenseClass = 'C';
  final List<String> _serviceRegions = [];
  bool _isAvailable = true;
  bool _isLoading = false;

  static const _vehicleTypes = [
    ('truck', '🚛 Truck'),
    ('pickup', '🛻 Pickup'),
    ('van', '🚐 Van'),
    ('lorry', '🚚 Lorry'),
    ('refrigerated', '❄️ Refrigerated'),
  ];

  static const _licenseClasses = ['A', 'B', 'C', 'D', 'E'];

  @override
  void dispose() {
    _licenseController.dispose();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId!;

      await SupabaseService.client.from('driver_profiles').upsert({
        'user_id': uid,
        'license_number': _licenseController.text.trim(),
        'license_class': _licenseClass,
        'vehicle_type': _vehicleType,
        'vehicle_make': _makeController.text.trim(),
        'vehicle_model': _modelController.text.trim(),
        'vehicle_year': int.tryParse(_yearController.text.trim()),
        'vehicle_plate': _plateController.text.trim().toUpperCase(),
        'vehicle_capacity_kg':
            double.tryParse(_capacityController.text.trim()),
        'service_regions': _serviceRegions,
        'is_available': _isAvailable,
        'verification_status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Driver profile saved!'),
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
          title: const Text('Driver Profile Setup')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.driverRole.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.driverRole.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Text('🚛', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set up your driver profile',
                              style: AppTextStyles.titleMedium),
                          Text(
                              'Complete this to receive transport job bids.',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Vehicle Type', style: AppTextStyles.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _vehicleTypes.map((t) {
                  final isSelected = _vehicleType == t.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _vehicleType = t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.driverRole
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSelected
                                ? AppColors.driverRole
                                : AppColors.border),
                      ),
                      child: Text(
                        t.$2,
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

              AppTextField(
                label: 'Vehicle Make',
                hint: 'e.g. Mercedes-Benz, Volvo, DAF',
                controller: _makeController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Model',
                      hint: 'Actros 2644',
                      controller: _modelController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Year',
                      hint: '2020',
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Number Plate',
                hint: 'GR-1234-20',
                controller: _plateController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Carrying Capacity (kg)',
                hint: '10000',
                controller: _capacityController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'License Number',
                hint: 'Your driver\'s license number',
                controller: _licenseController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Text('License Class',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _licenseClasses.map((c) {
                  final isSelected = _licenseClass == c;
                  return GestureDetector(
                    onTap: () => setState(() => _licenseClass = c),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 2),
                      ),
                      child: Center(
                        child: Text(c,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Service regions
              Text('Service Regions', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('Which regions do you operate in?',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.ghanaRegions.map((r) {
                  final isSelected = _serviceRegions.contains(r);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _serviceRegions.remove(r);
                      } else {
                        _serviceRegions.add(r);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.driverRole.withOpacity(0.12)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSelected
                                ? AppColors.driverRole
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1),
                      ),
                      child: Text(
                        r,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected
                              ? AppColors.driverRole
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Availability
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
                          Text('Available for Jobs',
                              style: AppTextStyles.titleSmall),
                          Text(
                            _isAvailable
                                ? 'You can receive transport job bids'
                                : 'You are currently not accepting jobs',
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
                label: 'Save Driver Profile',
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
