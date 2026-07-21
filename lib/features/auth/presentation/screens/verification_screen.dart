import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/auth_provider.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _picker = ImagePicker();
  final Map<String, File?> _documents = {
    'national_id': null,
    'credentials': null,
    'business_reg': null,
  };
  bool _isLoading = false;
  bool _isExpert = false;
  bool _isBusiness = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).value;
    if (user != null) {
      _isExpert = user.isExpert;
      _isBusiness = user.isBusiness;
    }
  }

  Future<void> _pickDocument(String key) async {
    final result = await _picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _documents[key] = File(result.path));
    }
  }

  Future<void> _submit() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      for (final entry in _documents.entries) {
        if (entry.value == null) continue;
        final bytes = await entry.value!.readAsBytes();
        final path = 'verifications/${user.id}/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await SupabaseService.uploadFile(
          bucket: AppConstants.verificationDocsBucket,
          path: path,
          bytes: bytes,
          contentType: 'image/jpeg',
        );

        await SupabaseService.client.from('verifications').insert({
          'user_id': user.id,
          'role': user.activeRole,
          'document_type': entry.key,
          'document_url': url,
          'status': 'pending',
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documents submitted! We\'ll review within 24–48 hours.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppConstants.routeHome);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verification'),
        actions: [
          TextButton(
            onPressed: () => context.go(AppConstants.routeHome),
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppColors.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Get Verified', style: AppTextStyles.titleMedium),
                          Text(
                            'Verification builds trust with other users and unlocks all platform features.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text('Required Documents', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 16),

              // National ID - always required
              _DocumentUploadTile(
                title: 'National ID / Passport / Voter\'s Card',
                subtitle: 'Required for all users',
                icon: Icons.badge_outlined,
                file: _documents['national_id'],
                onTap: () => _pickDocument('national_id'),
              ),
              const SizedBox(height: 12),

              // Expert credentials
              if (_isExpert) ...[
                _DocumentUploadTile(
                  title: 'Professional Credentials',
                  subtitle: 'Degree, Certificate, or Professional license',
                  icon: Icons.school_outlined,
                  file: _documents['credentials'],
                  onTap: () => _pickDocument('credentials'),
                ),
                const SizedBox(height: 12),
              ],

              // Business registration
              if (_isBusiness) ...[
                _DocumentUploadTile(
                  title: 'Business Registration Certificate',
                  subtitle: 'Ghana Revenue Authority or DUNS number',
                  icon: Icons.business_outlined,
                  file: _documents['business_reg'],
                  onTap: () => _pickDocument('business_reg'),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 32),

              // Note about review time
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Review takes 24–48 hours. You\'ll be notified via SMS and in-app notification.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              AppButton(
                label: 'Submit for Verification',
                onPressed: _documents['national_id'] == null || _isLoading
                    ? null
                    : _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final File? file;
  final VoidCallback onTap;

  const _DocumentUploadTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUploaded = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUploaded
              ? AppColors.success.withOpacity(0.1)
              : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUploaded ? AppColors.success : AppColors.border,
            width: isUploaded ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isUploaded
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUploaded ? Icons.check_circle_outline : icon,
                color: isUploaded ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  Text(
                    isUploaded ? 'Document uploaded ✓' : subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isUploaded
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isUploaded ? Icons.edit_outlined : Icons.upload_outlined,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
