import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class _RoleItem {
  final String value;
  final String label;
  final String emoji;
  final Color color;
  const _RoleItem(this.value, this.label, this.emoji, this.color);
}

const _allRoles = [
  _RoleItem('farmer', 'Farmer', '🌾', AppColors.farmerRole),
  _RoleItem('processing_industry', 'Processor', '🏭', AppColors.businessRole),
  _RoleItem('truck_driver', 'Driver', '🚛', AppColors.driverRole),
  _RoleItem('wholesaler', 'Wholesaler', '📦', AppColors.businessRole),
  _RoleItem('retailer', 'Retailer', '🏪', AppColors.businessRole),
  _RoleItem('expert', 'Expert', '🎓', AppColors.expertRole),
  _RoleItem('enthusiast', 'Enthusiast', '🌱', AppColors.enthusiastRole),
  _RoleItem('customer', 'Customer', '🛒', AppColors.customerRole),
];

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final Set<String> _selectedRoles = {'customer'};
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one role.');
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please accept the terms and conditions.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        final rolesList = _selectedRoles.toList();

        // Insert user profile with selected roles
        try {
          await SupabaseService.client.from('users').upsert({
            'id': response.user!.id,
            'full_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'roles': rolesList,
            'active_role': rolesList.first,
          });
        } catch (_) {}

        if (response.session != null) {
          // Needs verification? → go to verification, else home
          final needsVerification = _selectedRoles.any((r) =>
              r == 'expert' ||
              r == 'processing_industry' ||
              r == 'wholesaler' ||
              r == 'truck_driver');

          context.go(needsVerification
              ? AppConstants.routeVerification
              : AppConstants.routeHome);
        } else {
          // Email confirmation required
          _showEmailSentDialog();
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Check your email',
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'We sent a verification link to\n${_emailController.text.trim()}',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppConstants.routeLogin);
            },
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go(AppConstants.routeLogin),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Join AgroTec Ghana',
                  style: AppTextStyles.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Create your account to get started',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── Personal Info ──────────────────────────────────
              AppTextField(
                label: 'Full Name',
                hint: 'Kwame Mensah',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Name is required';
                  if (v.trim().length < 2) return 'Name is too short';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Email',
                hint: 'kwame@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Phone Number',
                hint: '+233 24 000 0000',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Password',
                hint: 'Min. 8 characters',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8)
                    return 'Password must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Confirm Password',
                hint: 'Repeat your password',
                controller: _confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                validator: (v) {
                  if (v != _passwordController.text)
                    return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ── Role Selection ─────────────────────────────────
              Row(
                children: [
                  Text('I am a...', style: AppTextStyles.titleLarge),
                  const SizedBox(width: 8),
                  Text('(select all that apply)',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allRoles.map((role) {
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
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? role.color.withOpacity(0.12)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? role.color : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(role.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            role.label,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: isSelected
                                  ? role.color
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle,
                                size: 14, color: role.color),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Terms ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _agreedToTerms = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _agreedToTerms = !_agreedToTerms),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            text: 'I agree to the ',
                            style: AppTextStyles.bodySmall,
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Error ──────────────────────────────────────────
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ),

              // ── Submit ─────────────────────────────────────────
              AppButton(
                label: 'Create Account',
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => context.go(AppConstants.routeLogin),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Sign in',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
