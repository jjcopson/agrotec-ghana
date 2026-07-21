import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class CreateTransportJobScreen extends ConsumerStatefulWidget {
  const CreateTransportJobScreen({super.key});

  @override
  ConsumerState<CreateTransportJobScreen> createState() =>
      _CreateTransportJobScreenState();
}

class _CreateTransportJobScreenState
    extends ConsumerState<CreateTransportJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _cargoTypeController = TextEditingController();
  final _weightController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _budgetController = TextEditingController();

  String _pickupRegion = 'Greater Accra';
  String _deliveryRegion = 'Ashanti';
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  final List<File> _images = [];
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cargoTypeController.dispose();
    _weightController.dispose();
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 4) return;
    final r = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (r != null) setState(() => _images.add(File(r.path)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _pickupDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = SupabaseService.currentUserId!;
      final imageUrls = <String>[];

      for (final img in _images) {
        final bytes = await img.readAsBytes();
        final path =
            'transport/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await SupabaseService.uploadFile(
          bucket: AppConstants.listingImagesBucket,
          path: path,
          bytes: bytes,
          contentType: 'image/jpeg',
        );
        imageUrls.add(url);
      }

      await SupabaseService.client.from('transport_jobs').insert({
        'poster_id': uid,
        'status': 'open',
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'cargo_type': _cargoTypeController.text.trim(),
        'cargo_weight_kg': _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
        'cargo_images': imageUrls,
        'pickup_address': _pickupAddressController.text.trim(),
        'pickup_region': _pickupRegion,
        'pickup_date': DateFormat('yyyy-MM-dd').format(_pickupDate),
        'delivery_address': _deliveryAddressController.text.trim(),
        'delivery_region': _deliveryRegion,
        'budget_ghs': _budgetController.text.isNotEmpty
            ? double.tryParse(_budgetController.text)
            : null,
        'payment_status': 'unpaid',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transport job posted! Drivers can now bid.'),
          backgroundColor: AppColors.success));
      context.go(AppConstants.routeTransport);
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
          title: const Text('Post Transport Job')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Job Title',
                hint: 'e.g. Transport 500 bags of maize from Kumasi to Accra',
                controller: _titleController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Cargo Type',
                hint: 'e.g. Maize, Tomatoes, Equipment',
                controller: _cargoTypeController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Weight (kg) — optional',
                hint: '500',
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),

              // Cargo images
              Text('Cargo Photos (optional)',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primary),
                      ),
                    ),
                    ..._images.map((f) => Container(
                          width: 72,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                                image: FileImage(f),
                                fit: BoxFit.cover),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Pickup Details', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Pickup Address',
                hint: 'e.g. Kumasi Central Market',
                controller: _pickupAddressController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Pickup region
              Text('Pickup Region',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _pickupRegion,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                ),
                items: AppConstants.ghanaRegions
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _pickupRegion = v!),
              ),
              const SizedBox(height: 12),

              // Pickup date
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Pickup Date: ${DateFormat('MMM d, yyyy').format(_pickupDate)}',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Delivery Details', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Delivery Address',
                hint: 'e.g. Makola Market, Accra',
                controller: _deliveryAddressController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Delivery region
              Text('Delivery Region',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _deliveryRegion,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                ),
                items: AppConstants.ghanaRegions
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _deliveryRegion = v!),
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Budget (₵) — optional',
                hint: '200.00',
                controller: _budgetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Additional Details — optional',
                hint:
                    'Any special handling requirements, fragile goods, etc.',
                controller: _descController,
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Post Job',
                onPressed: _isLoading ? null : _submit,
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
