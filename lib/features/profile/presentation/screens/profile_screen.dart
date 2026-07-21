import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/role_badge.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  File? _newAvatar;
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  String? _selectedRegion;
  String? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).value;
    _nameController = TextEditingController(text: user?.fullName);
    _bioController = TextEditingController(text: user?.bio);
    _phoneController = TextEditingController(text: user?.phone);
    _selectedRegion = user?.region;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (result != null) setState(() => _newAvatar = File(result.path));
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final uid = SupabaseService.currentUserId!;
      String? avatarUrl;

      if (_newAvatar != null) {
        final bytes = await _newAvatar!.readAsBytes();
        final path = 'avatars/$uid.jpg';
        avatarUrl = await SupabaseService.uploadFile(
          bucket: AppConstants.avatarsBucket,
          path: path,
          bytes: bytes,
          contentType: 'image/jpeg',
        );
      }

      final updates = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'region': _selectedRegion,
      };
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', uid);

      await ref.read(authNotifierProvider.notifier).refreshUser();
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: Size.zero),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Sign out from Supabase — clears session everywhere
    await SupabaseService.auth.signOut();

    if (!mounted) return;
    context.go(AppConstants.routeLogin);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authNotifierProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go(AppConstants.routeLogin));
          return const Scaffold(body: SizedBox());
        }
        return _buildProfile(user);
      },
    );
  }

  Widget _buildProfile(UserModel user) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Edit'),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _isEditing ? _pickAvatar : null,
                    child: Stack(
                      children: [
                        _newAvatar != null
                            ? Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: FileImage(_newAvatar!),
                                    fit: BoxFit.cover,
                                  ),
                                  border: Border.all(
                                      color: AppColors.primary, width: 2),
                                ),
                              )
                            : AppAvatar(
                                imageUrl: user.avatarUrl,
                                name: user.fullName,
                                size: 88,
                                showVerified: user.isVerified,
                              ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!_isEditing) ...[
                    Text(user.fullName,
                        style: AppTextStyles.headlineMedium),
                    if (user.username != null)
                      Text('@${user.username}',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    // Role badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: user.roles
                          .map((r) => RoleBadge(role: r))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Text(user.bio!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary)),
                    if (user.region != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(user.region!,
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Edit form
            if (_isEditing) ...[
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Profile',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Full Name',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Bio',
                      hint: 'Tell people about yourself...',
                      controller: _bioController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Phone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Text('Region',
                        style: AppTextStyles.titleSmall
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedRegion,
                      hint: const Text('Select region'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.border)),
                      ),
                      items: AppConstants.ghanaRegions
                          .map((r) => DropdownMenuItem(
                              value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedRegion = v),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Save Changes',
                      onPressed: _isSaving ? null : _saveProfile,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Verification status
            _VerificationCard(user: user),
            const SizedBox(height: 12),

            // Quick stats
            if (!_isEditing) ...[
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.account_circle_outlined,
                      label: 'Manage Roles',
                      onTap: () =>
                          context.go(AppConstants.routeRoleSelect),
                    ),
                    // Role-specific setup links
                    if (user.isFarmer)
                      _SettingsTile(
                        icon: Icons.agriculture_outlined,
                        label: 'Farm Profile',
                        onTap: () => context.go('/profile/setup-farmer'),
                      ),
                    if (user.isExpert)
                      _SettingsTile(
                        icon: Icons.school_outlined,
                        label: 'Expert Profile',
                        onTap: () => context.go('/profile/setup-expert'),
                      ),
                    if (user.isDriver)
                      _SettingsTile(
                        icon: Icons.local_shipping_outlined,
                        label: 'Driver Profile',
                        onTap: () => context.go('/profile/setup-driver'),
                      ),
                    _SettingsTile(
                      icon: Icons.verified_outlined,
                      label: 'Verification',
                      onTap: () =>
                          context.go(AppConstants.routeVerification),
                    ),
                    _SettingsTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'My Wallet',
                      onTap: () => context.go(AppConstants.routeWallet),
                    ),
                    _SettingsTile(
                      icon: Icons.shopping_bag_outlined,
                      label: 'My Orders',
                      onTap: () => context.go(AppConstants.routeOrders),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () =>
                          context.go(AppConstants.routeNotifications),
                    ),
                    const Divider(height: 24),
                    _SettingsTile(
                      icon: Icons.logout,
                      label: 'Sign Out',
                      color: AppColors.error,
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // App version
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final UserModel user;
  const _VerificationCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: user.isVerified
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              user.isVerified
                  ? Icons.verified
                  : Icons.pending_outlined,
              color: user.isVerified
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.isVerified
                      ? 'Account Verified'
                      : 'Verification Pending',
                  style: AppTextStyles.titleSmall,
                ),
                Text(
                  user.isVerified
                      ? 'Your account is fully verified.'
                      : 'Submit documents to unlock all features.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!user.isVerified)
            TextButton(
              onPressed: () =>
                  context.go(AppConstants.routeVerification),
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: AppTextStyles.bodyMedium.copyWith(color: c)),
      trailing: color == null
          ? const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
