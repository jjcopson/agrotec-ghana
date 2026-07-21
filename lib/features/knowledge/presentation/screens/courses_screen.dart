import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/supabase_service.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String _difficulty = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _difficulties = [
    ('all', 'All Levels'),
    ('beginner', 'Beginner'),
    ('intermediate', 'Intermediate'),
    ('advanced', 'Advanced'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      dynamic query = SupabaseService.client
          .from('courses')
          .select('*, users(full_name, avatar_url)')
          .eq('status', 'published');

      if (_difficulty != 'all') {
        query = (query as dynamic).eq('difficulty', _difficulty);
      }

      final data = await (query as dynamic)
          .order('enrolled_count', ascending: false);
      var courses = List<Map<String, dynamic>>.from(data as List);

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        courses = courses
            .where((c) =>
                (c['title'] as String?)
                    ?.toLowerCase()
                    .contains(q) ??
                false)
            .toList();
      }

      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.white,
          title: const Text('Courses')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Difficulty filter
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _difficulties.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = _difficulties[i];
                final isSelected = _difficulty == d.$1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _difficulty = d.$1;
                      _isLoading = true;
                    });
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
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
                    child: Text(d.$2,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _courses.isEmpty
                    ? const Center(child: Text('No courses found'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _courses.length,
                        itemBuilder: (ctx, i) {
                          final c = _courses[i];
                          final inst = c['users']
                              as Map<String, dynamic>?;
                          return GestureDetector(
                            onTap: () => context
                                .go('/knowledge/courses/${c['id']}'),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(15)),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: c['cover_image_url'] != null
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  c['cover_image_url'],
                                              fit: BoxFit.cover)
                                          : Container(
                                              color: AppColors.primarySurface,
                                              child: const Center(
                                                  child: Text('📚',
                                                      style: TextStyle(
                                                          fontSize: 32)))),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(c['title'] ?? '',
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: AppTextStyles
                                                .titleSmall
                                                .copyWith(fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(
                                            inst?['full_name'] ??
                                                'Instructor',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(fontSize: 10),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        _DifficultyBadge(
                                            c['difficulty'] ??
                                                'beginner'),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                size: 12,
                                                color: AppColors.warning),
                                            Text(
                                                ' ${(c['rating'] ?? 0.0).toStringAsFixed(1)}',
                                                style: AppTextStyles
                                                    .labelSmall
                                                    .copyWith(
                                                        fontSize: 10)),
                                            const Spacer(),
                                            Text(
                                              c['is_free'] == true
                                                  ? 'Free'
                                                  : '₵${(c['price_ghs'] ?? 0).toStringAsFixed(0)}',
                                              style: AppTextStyles
                                                  .labelSmall
                                                  .copyWith(
                                                      color: AppColors
                                                          .primary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge(this.difficulty);

  @override
  Widget build(BuildContext context) {
    final config = switch (difficulty) {
      'beginner' => ('Beginner', AppColors.success),
      'intermediate' => ('Intermediate', AppColors.warning),
      'advanced' => ('Advanced', AppColors.error),
      _ => (difficulty, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: config.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(config.$1,
          style: AppTextStyles.labelSmall
              .copyWith(color: config.$2, fontSize: 9)),
    );
  }
}
