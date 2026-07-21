import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();

  String _category = 'crops';
  String _unit = 'kg';
  String _region = 'Greater Accra';
  bool _isNegotiable = false;
  bool _deliveryAvailable = false;
  bool _pickupAvailable = true;
  bool _isLoading = false;

  // Store image bytes for web compatibility
  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];
  final _picker = ImagePicker();

  static const _categories = [
    ('crops', '🌾 Crops'),
    ('livestock', '🐄 Livestock'),
    ('equipment', '🚜 Equipment'),
    ('inputs', '🌱 Inputs'),
    ('processed_goods', '📦 Processed Goods'),
    ('seeds', '🫘 Seeds'),
    ('fertilizers', '🧪 Fertilizers'),
    ('pesticides', '🧴 Pesticides'),
    ('irrigation', '💧 Irrigation'),
    ('other', '📦 Other'),
  ];

  static const _units = [
    'kg', 'bag', 'crate', 'piece', 'litre',
    'tonne', 'dozen', 'bunch', 'basket',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imageBytes.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 images allowed')));
      return;
    }
    try {
      final result = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (result == null) return;
      final bytes = await result.readAsBytes();
      setState(() {
        _imageBytes.add(bytes);
        _imageNames.add(result.name);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUserId!;
      final imageUrls = <String>[];

      // Upload images
      for (int i = 0; i < _imageBytes.length; i++) {
        final path =
            'listings/$userId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await SupabaseService.uploadFile(
          bucket: AppConstants.listingImagesBucket,
          path: path,
          bytes: _imageBytes[i],
          contentType: 'image/jpeg',
        );
        imageUrls.add(url);
      }

      await SupabaseService.client.from('marketplace_listings').insert({
        'seller_id': userId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _category,
        'price_ghs': double.parse(_priceController.text.trim()),
        'unit': _unit,
        'quantity': double.parse(_quantityController.text.trim()),
        'quantity_available': double.parse(_quantityController.text.trim()),
        'images': imageUrls,
        'location': _locationController.text.trim(),
        'region': _region,
        'is_negotiable': _isNegotiable,
        'delivery_available': _deliveryAvailable,
        'pickup_available': _pickupAvailable,
        'status': 'active',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Listing published successfully!'),
          backgroundColor: AppColors.success));
      context.go(AppConstants.routeMarketplace);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
        title: const Text('Create Listing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go(AppConstants.routeMarketplace),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Images ────────────────────────────────────────
              Text('Product Photos', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text('Add up to 5 photos of your product',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 10),

              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add button
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 92,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                color: AppColors.primary, size: 30),
                            const SizedBox(height: 4),
                            Text('Add Photo',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                    // Uploaded images
                    ..._imageBytes.asMap().entries.map((e) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 92,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: MemoryImage(e.value),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _imageBytes.removeAt(e.key);
                                  _imageNames.removeAt(e.key);
                                }),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 13, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Product Info ──────────────────────────────────
              Text('Product Details', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),

              AppTextField(
                label: 'Title',
                hint: 'e.g. Fresh Maize from Brong-Ahafo',
                controller: _titleController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Description',
                hint:
                    'Describe your product — quality, harvest date, how to use...',
                controller: _descController,
                maxLines: 4,
              ),
              const SizedBox(height: 14),

              // Category
              _DropdownField(
                label: 'Category',
                value: _category,
                items: _categories.map((c) => (c.$1, c.$2)).toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 14),

              // Price + Unit row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: 'Price (₵)',
                      hint: '0.00',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('₵',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null)
                          return 'Invalid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropdownField(
                      label: 'Unit',
                      value: _unit,
                      items: _units.map((u) => (u, u)).toList(),
                      onChanged: (v) => setState(() => _unit = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Quantity Available',
                hint: '100',
                controller: _quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Location ──────────────────────────────────────
              Text('Location', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),

              AppTextField(
                label: 'Specific Location / Market',
                hint: 'e.g. Kumasi Central Market',
                controller: _locationController,
              ),
              const SizedBox(height: 14),

              _DropdownField(
                label: 'Region',
                value: _region,
                items: AppConstants.ghanaRegions
                    .map((r) => (r, r))
                    .toList(),
                onChanged: (v) => setState(() => _region = v),
              ),
              const SizedBox(height: 20),

              // ── Options ───────────────────────────────────────
              Text('Options', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),

              _ToggleRow(
                label: 'Price is Negotiable',
                subtitle: 'Buyers can make offers',
                value: _isNegotiable,
                onChanged: (v) => setState(() => _isNegotiable = v),
              ),
              _ToggleRow(
                label: 'Delivery Available',
                subtitle: 'You can deliver to buyers',
                value: _deliveryAvailable,
                onChanged: (v) =>
                    setState(() => _deliveryAvailable = v),
              ),
              _ToggleRow(
                label: 'Pickup Available',
                subtitle: 'Buyers can pick up from you',
                value: _pickupAvailable,
                onChanged: (v) =>
                    setState(() => _pickupAvailable = v),
              ),
              const SizedBox(height: 28),

              AppButton(
                label: 'Publish Listing',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
                prefixIcon: const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> items;
  final void Function(String) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.titleSmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item.$1,
                    child: Text(item.$2),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? AppColors.primarySurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: value ? AppColors.primary.withOpacity(0.3) : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.titleSmall),
                Text(subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
