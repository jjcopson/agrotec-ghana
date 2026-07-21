import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_avatar.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() =>
      _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;
  bool _isEnrolled = false;
  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final course = await SupabaseService.client
          .from('courses')
          .select('*, users(full_name, avatar_url)')
          .eq('id', widget.courseId)
          .single();

      final sections = await SupabaseService.client
          .from('course_sections')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index');

      final lessons = await SupabaseService.client
          .from('course_lessons')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index');

      // Check enrollment
      bool enrolled = false;
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        final enroll = await SupabaseService.client
            .from('course_enrollments')
            .select('id, payment_status')
            .eq('course_id', widget.courseId)
            .eq('user_id', uid)
            .maybeSingle();
        enrolled = enroll != null &&
            (enroll['payment_status'] == 'paid' ||
                (course['is_free'] == true));
      }

      setState(() {
        _course = course;
        _sections = List<Map<String, dynamic>>.from(sections as List);
        _lessons = List<Map<String, dynamic>>.from(lessons as List);
        _isEnrolled = enrolled;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enroll() async {
    if (_course == null) return;
    final isFree = _course!['is_free'] == true ||
        (_course!['price_ghs'] as num?) == 0;

    if (isFree) {
      setState(() => _isEnrolling = true);
      try {
        await SupabaseService.client
            .from('course_enrollments')
            .insert({
          'course_id': widget.courseId,
          'user_id': SupabaseService.currentUserId,
          'payment_status': 'paid',
          'amount_paid_ghs': 0,
        });
        setState(() => _isEnrolled = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Enrolled! Start learning.'),
              backgroundColor: AppColors.success));
        }
      } finally {
        if (mounted) setState(() => _isEnrolling = false);
      }
    } else {
      _showPaymentSheet();
    }
  }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoursePaymentSheet(
        course: _course!,
        onSuccess: () {
          setState(() => _isEnrolled = true);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_course == null) {
      return const Scaffold(
          body: Center(child: Text('Course not found')));
    }

    final c = _course!;
    final instructor = c['users'] as Map<String, dynamic>?;
    final isFree =
        c['is_free'] == true || (c['price_ghs'] as num?) == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: c['cover_image_url'] != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                            imageUrl: c['cover_image_url'],
                            fit: BoxFit.cover),
                        Container(
                            color: Colors.black.withOpacity(0.3)),
                      ],
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                        ),
                      ),
                      child: const Center(
                          child: Text('📚',
                              style: TextStyle(fontSize: 64))),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['title'] ?? '',
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 16, color: AppColors.warning),
                      Text(
                        ' ${(c['rating'] ?? 0.0).toStringAsFixed(1)}',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.people_outline,
                          size: 16, color: AppColors.textSecondary),
                      Text(
                        ' ${c['enrolled_count'] ?? 0} enrolled',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        isFree
                            ? 'Free'
                            : '₵${(c['price_ghs'] as num).toStringAsFixed(2)}',
                        style: AppTextStyles.priceLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Instructor
                  Row(
                    children: [
                      AppAvatar(
                        imageUrl: instructor?['avatar_url'],
                        name: instructor?['full_name'],
                        size: 40,
                        showVerified: true,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instructor',
                              style: AppTextStyles.bodySmall
                                  .copyWith(
                                      color: AppColors.textSecondary)),
                          Text(instructor?['full_name'] ?? 'Expert',
                              style: AppTextStyles.titleSmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (c['description'] != null) ...[
                    Text('About this course',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Text(c['description'],
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary,
                                height: 1.6)),
                    const SizedBox(height: 24),
                  ],

                  // Curriculum
                  Text('Curriculum',
                      style: AppTextStyles.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${_lessons.length} lessons',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  if (_sections.isEmpty)
                    ..._lessons.map((lesson) => _LessonTile(
                          lesson: lesson,
                          isEnrolled: _isEnrolled,
                        ))
                  else
                    ..._sections.map((section) {
                      final sectionLessons = _lessons
                          .where((l) =>
                              l['section_id'] == section['id'])
                          .toList();
                      return _SectionExpansion(
                        section: section,
                        lessons: sectionLessons,
                        isEnrolled: _isEnrolled,
                      );
                    }),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isEnrolled
          ? Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              color: AppColors.white,
              child: AppButton(
                label: 'Continue Learning',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
            )
          : Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: AppButton(
                label: isFree
                    ? 'Enroll for Free'
                    : 'Enroll — ₵${(c['price_ghs'] as num).toStringAsFixed(2)}',
                onPressed: _isEnrolling ? null : _enroll,
                isLoading: _isEnrolling,
              ),
            ),
    );
  }
}

class _SectionExpansion extends StatefulWidget {
  final Map<String, dynamic> section;
  final List<Map<String, dynamic>> lessons;
  final bool isEnrolled;
  const _SectionExpansion(
      {required this.section,
      required this.lessons,
      required this.isEnrolled});

  @override
  State<_SectionExpansion> createState() => _SectionExpansionState();
}

class _SectionExpansionState extends State<_SectionExpansion> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(widget.section['title'] ?? '',
                    style: AppTextStyles.titleMedium),
                const Spacer(),
                Text('${widget.lessons.length} lessons',
                    style: AppTextStyles.bodySmall),
                const SizedBox(width: 4),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.lessons.map((l) => _LessonTile(
                lesson: l,
                isEnrolled: widget.isEnrolled,
              )),
        const Divider(height: 1),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Map<String, dynamic> lesson;
  final bool isEnrolled;
  const _LessonTile({required this.lesson, required this.isEnrolled});

  @override
  Widget build(BuildContext context) {
    final isPreview = lesson['is_preview'] == true;
    final isLocked = !isEnrolled && !isPreview;
    final duration = lesson['duration_mins'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLocked ? AppColors.surfaceVariant : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLocked
                  ? AppColors.textTertiary.withOpacity(0.1)
                  : AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLocked
                  ? Icons.lock_outline
                  : (lesson['video_url'] != null
                      ? Icons.play_circle_outline
                      : Icons.article_outlined),
              size: 18,
              color: isLocked ? AppColors.textTertiary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson['title'] ?? '',
                    style: AppTextStyles.titleSmall.copyWith(
                        color: isLocked
                            ? AppColors.textTertiary
                            : AppColors.textPrimary)),
                if (duration != null)
                  Text('${duration} min',
                      style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (isPreview && !isEnrolled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Preview',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.success, fontSize: 10)),
            ),
        ],
      ),
    );
  }
}

class _CoursePaymentSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> course;
  final VoidCallback onSuccess;
  const _CoursePaymentSheet(
      {required this.course, required this.onSuccess});

  @override
  ConsumerState<_CoursePaymentSheet> createState() =>
      _CoursePaymentSheetState();
}

class _CoursePaymentSheetState
    extends ConsumerState<_CoursePaymentSheet> {
  String _paymentMethod = 'wallet';
  bool _isProcessing = false;

  Future<void> _pay() async {
    setState(() => _isProcessing = true);
    try {
      final price = (widget.course['price_ghs'] as num).toDouble();
      await SupabaseService.client
          .from('course_enrollments')
          .insert({
        'course_id': widget.course['id'],
        'user_id': SupabaseService.currentUserId,
        'payment_status': 'paid',
        'amount_paid_ghs': price,
      });

      // Deduct from wallet via edge function
      await SupabaseService.client.functions.invoke(
        'process-course-payment',
        body: {
          'course_id': widget.course['id'],
          'user_id': SupabaseService.currentUserId,
          'amount_ghs': price,
          'payment_method': _paymentMethod,
        },
      );

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (widget.course['price_ghs'] as num).toDouble();
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Enroll in Course', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(widget.course['title'] ?? '',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Course Fee', style: AppTextStyles.titleMedium),
              Text(
                '${AppConstants.currencySymbol}${price.toStringAsFixed(2)}',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Pay with', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _Chip('wallet', 'Wallet', _paymentMethod,
                  (v) => setState(() => _paymentMethod = v)),
              const SizedBox(width: 8),
              _Chip('momo', 'MoMo', _paymentMethod,
                  (v) => setState(() => _paymentMethod = v)),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Pay & Enroll',
            isLoading: _isProcessing,
            onPressed: _pay,
          ),
        ],
      ),
    );
  }
}

Widget _Chip(String value, String label, String selected,
    void Function(String) onTap) {
  final isSelected = selected == value;
  return GestureDetector(
    onTap: () => onTap(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySurface : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1),
      ),
      child: Text(label,
          style: AppTextStyles.labelMedium.copyWith(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary)),
    ),
  );
}
