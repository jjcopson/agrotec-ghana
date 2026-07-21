import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class SetupFarmerProfileScreen extends ConsumerStatefulWidget {
  const SetupFarmerProfileScreen({super.key});

  @override
  ConsumerState<SetupFarmerProfileScreen> createState() =>
      _SetupFarmerProfileScreenState();
}

class _SetupFarmerProfileScreenState
    extends ConsumerState<SetupFarmerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _farmSizeController = TextEditingController();
  final _farmLocationController = TextEditingController();
  final _yearsController = TextEditingController();
  final _cropInput = TextEditingController();
  final _livestockInput = TextEditingController();

  String _farmingType = 'conventional';
  String _region = 'Greater Accra';
  final List<String> _crops = [];
  final List<String> _livestock = [];
  bool _isLoading = false;

  static const _farmingTypes = [
    ('conventional', '🌾 Conventional'),
    ('organic', '🌿 Organic'),
    ('mixed', '🔄 Mixed'),
  ];

  @override
  void dispose() {
    _farmNameController.dispose();
    _farmSizeController.dispose();
    _farmLocationController.dispose();
    _yearsController.dispose();
    _cropInput.dispose();
    _livestockInput.dispose();
    super.dispose();
  }

  void _addCrop() {
    final val = _cropInput.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _crops.add(val);
      _cropInput.clear();
    });
  }

  void _addLivestock() {
    final val = _livestockInput.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _livestock.add(val);
      _livestockInput.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId!;

      await SupabaseService.client.from('users').update({
        'region': _region,
      }).eq('id', uid);

      await SupabaseService.client.from('farmer_profiles').upsert({
        'user_id': uid,
        'farm_name': _farmNameController.text.trim(),
        'farm_size_acres': double.tryParse(_farmSizeController.text.trim()),
        'farm_location': _farmLocationController.text.trim(),
        'crops_grown': _crops,
        'livestock': _livestock,
        'farming_type': _farmingType,
        'years_farming': int.tryParse(_yearsController.text.trim()),
        'verification_status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Farmer profile saved!'),
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
          title: const Text('Farm Profile Setup')),
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
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🌾', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tell us about your farm',
                              style: AppTextStyles.titleMedium),
                          Text(
                              'This helps buyers find your produce and builds trust.',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'Farm Name',
                hint: 'e.g. Mensah Family Farm',
                controller: _farmNameController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Farm name is required' : null,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Farm Size (acres) — optional',
                hint: '5.0',
                controller: _farmSizeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Farm Location / Area',
                hint: 'e.g. Ejura, Ashanti',
                controller: _farmLocationController,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Years Farming — optional',
                hint: '10',
                controller: _yearsController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              // Region
              _DropLabel('Region'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _region,
                decoration: _dropDecoration(),
                items: AppConstants.ghanaRegions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _region = v!),
              ),
              const SizedBox(height: 14),

              // Farming type
              _DropLabel('Farming Type'),
              const SizedBox(height: 8),
              Row(
                children: _farmingTypes.map((t) {
                  final isSelected = _farmingType == t.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _farmingType = t.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary
                                  : AppColors.border),
                        ),
                        child: Text(
                          t.$2,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Crops
              Text('Crops Grown', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('e.g. Maize, Tomatoes, Cassava, Yam',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _TagInput(
                controller: _cropInput,
                hint: 'Add a crop...',
                onAdd: _addCrop,
                tags: _crops,
                onRemove: (c) => setState(() => _crops.remove(c)),
                color: AppColors.secondary,
              ),
              const SizedBox(height: 20),

              // Livestock
              Text('Livestock', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('e.g. Cattle, Goats, Poultry, Pigs',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _TagInput(
                controller: _livestockInput,
                hint: 'Add livestock...',
                onAdd: _addLivestock,
                tags: _livestock,
                onRemove: (l) => setState(() => _livestock.remove(l)),
                color: AppColors.warning,
              ),
              const SizedBox(height: 28),

              AppButton(
                label: 'Save Farm Profile',
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

Widget _DropLabel(String label) => Text(label,
    style: AppTextStyles.titleSmall
        .copyWith(color: AppColors.textSecondary));

InputDecoration _dropDecoration() => InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

class _TagInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final List<String> tags;
  final void Function(String) onRemove;
  final Color color;

  const _TagInput({
    required this.controller,
    required this.hint,
    required this.onAdd,
    required this.tags,
    required this.onRemove,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map((t) => Chip(
                      label: Text(t),
                      onDeleted: () => onRemove(t),
                      backgroundColor: color.withOpacity(0.1),
                      deleteIconColor: color,
                      side: BorderSide.none,
                      labelStyle: TextStyle(color: color),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
