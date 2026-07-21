import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_avatar.dart';

class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _forumPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final posts = await SupabaseService.client
          .from('knowledge_posts')
          .select('*, users(full_name, avatar_url)')
          .eq('status', 'published')
          .order('published_at', ascending: false)
          .limit(20);

      final courses = await SupabaseService.client
          .from('courses')
          .select('*, users(full_name, avatar_url)')
          .eq('status', 'published')
          .order('enrolled_count', ascending: false)
          .limit(10);

      final forum = await SupabaseService.client
          .from('forum_posts')
          .select('*, users(full_name, avatar_url)')
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(15);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(posts as List);
        _courses = List<Map<String, dynamic>>.from(courses as List);
        _forumPosts = List<Map<String, dynamic>>.from(forum as List);
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
        title: const Text('Knowledge Hub'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Articles'),
            Tab(text: 'Forum'),
            Tab(text: 'Courses'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ArticlesTab(posts: _posts),
                _ForumTab(posts: _forumPosts),
                _CoursesPreviewTab(courses: _courses),
              ],
            ),
    );
  }
}

class _ArticlesTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _ArticlesTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
          child: Text('No articles yet. Check back soon!'));
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, i) {
          final post = posts[i];
          final author = post['users'] as Map<String, dynamic>?;
          final isFirst = i == 0;

          if (isFirst) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeaturedArticle(post: post, author: author),
                const SizedBox(height: 20),
                Text('Latest Articles',
                    style: AppTextStyles.headlineSmall),
                const SizedBox(height: 12),
              ],
            );
          }

          return _ArticleCard(post: post, author: author);
        },
      ),
    );
  }
}

class _FeaturedArticle extends StatelessWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? author;
  const _FeaturedArticle({required this.post, this.author});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/knowledge/post/${post['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['cover_image_url'] != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: post['cover_image_url'],
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primarySurface,
                      child: const Center(
                          child: Text('📰',
                              style: TextStyle(fontSize: 48))),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 160,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(19)),
                ),
                child: const Center(
                    child:
                        Text('📰', style: TextStyle(fontSize: 48))),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Featured',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Text(post['title'] ?? '',
                      style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 6),
                  if (post['summary'] != null)
                    Text(post['summary'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AppAvatar(
                        imageUrl: author?['avatar_url'],
                        name: author?['full_name'],
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(author?['full_name'] ?? 'Author',
                          style: AppTextStyles.bodySmall),
                      const Spacer(),
                      if (post['published_at'] != null)
                        Text(
                          timeago.format(
                              DateTime.parse(post['published_at'])),
                          style: AppTextStyles.bodySmall,
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
  }
}

class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? author;
  const _ArticleCard({required this.post, this.author});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/knowledge/post/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: post['cover_image_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: post['cover_image_url'],
                        fit: BoxFit.cover)
                    : Container(
                        color: AppColors.primarySurface,
                        child: const Center(
                            child: Text('📰',
                                style: TextStyle(fontSize: 28)))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(author?['full_name'] ?? 'Author',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite_outlined,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 2),
                      Text('${post['likes_count'] ?? 0}',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(width: 8),
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('${post['views_count'] ?? 0}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForumTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  const _ForumTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No forum posts yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p = posts[i];
        final author = p['users'] as Map<String, dynamic>?;
        return GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p['is_solved'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Solved ✓',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.success)),
                  ),
                Text(p['title'] ?? '',
                    style: AppTextStyles.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppAvatar(
                        imageUrl: author?['avatar_url'],
                        name: author?['full_name'],
                        size: 20),
                    const SizedBox(width: 6),
                    Text(author?['full_name'] ?? 'User',
                        style: AppTextStyles.bodySmall),
                    const Spacer(),
                    const Icon(Icons.question_answer_outlined,
                        size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text('${p['answers_count'] ?? 0} answers',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoursesPreviewTab extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  const _CoursesPreviewTab({required this.courses});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('All Courses', style: AppTextStyles.headlineSmall),
              TextButton(
                onPressed: () => context.go('/knowledge/courses'),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: courses.isEmpty
              ? const Center(child: Text('No courses yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (ctx, i) {
                    final c = courses[i];
                    final instructor =
                        c['users'] as Map<String, dynamic>?;
                    return GestureDetector(
                      onTap: () =>
                          context.go('/knowledge/courses/${c['id']}'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  const BorderRadius.vertical(
                                      top: Radius.circular(13)),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: c['cover_image_url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: c['cover_image_url'],
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
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleSmall
                                          .copyWith(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                      instructor?['full_name'] ??
                                          'Instructor',
                                      style: AppTextStyles.bodySmall
                                          .copyWith(fontSize: 10)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 12,
                                          color: AppColors.warning),
                                      Text(
                                          ' ${(c['rating'] ?? 0.0).toStringAsFixed(1)}',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(fontSize: 10)),
                                      const Spacer(),
                                      Text(
                                        c['is_free'] == true
                                            ? 'Free'
                                            : '₵${(c['price_ghs'] ?? 0).toStringAsFixed(0)}',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                                color: AppColors.primary,
                                                fontSize: 11,
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
    );
  }
}
