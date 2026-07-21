import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_avatar.dart';

class KnowledgePostScreen extends ConsumerStatefulWidget {
  final String postId;
  const KnowledgePostScreen({super.key, required this.postId});

  @override
  ConsumerState<KnowledgePostScreen> createState() =>
      _KnowledgePostScreenState();
}

class _KnowledgePostScreenState extends ConsumerState<KnowledgePostScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _hasLiked = false;
  final _commentController = TextEditingController();
  bool _isCommenting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final post = await SupabaseService.client
          .from('knowledge_posts')
          .select('*, users(full_name, avatar_url)')
          .eq('id', widget.postId)
          .single();

      final comments = await SupabaseService.client
          .from('knowledge_post_comments')
          .select('*, users(full_name, avatar_url)')
          .eq('post_id', widget.postId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: true);

      // check if current user liked
      bool liked = false;
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        final likeData = await SupabaseService.client
            .from('knowledge_post_likes')
            .select('id')
            .eq('post_id', widget.postId)
            .eq('user_id', uid)
            .maybeSingle();
        liked = likeData != null;
      }

      setState(() {
        _post = post;
        _comments =
            List<Map<String, dynamic>>.from(comments as List);
        _hasLiked = liked;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    if (_hasLiked) {
      await SupabaseService.client
          .from('knowledge_post_likes')
          .delete()
          .eq('post_id', widget.postId)
          .eq('user_id', uid);
      setState(() {
        _hasLiked = false;
        _post!['likes_count'] =
            (_post!['likes_count'] as int) - 1;
      });
    } else {
      await SupabaseService.client
          .from('knowledge_post_likes')
          .insert({'post_id': widget.postId, 'user_id': uid});
      setState(() {
        _hasLiked = true;
        _post!['likes_count'] =
            (_post!['likes_count'] as int) + 1;
      });
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    setState(() => _isCommenting = true);
    try {
      await SupabaseService.client.from('knowledge_post_comments').insert({
        'post_id': widget.postId,
        'user_id': uid,
        'content': content,
      });
      _commentController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _isCommenting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_post == null) {
      return const Scaffold(
          body: Center(child: Text('Post not found')));
    }

    final p = _post!;
    final author = p['users'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image
                  if (p['cover_image_url'] != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: p['cover_image_url'],
                        fit: BoxFit.cover,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags
                        if (p['tags'] != null &&
                            (p['tags'] as List).isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: (p['tags'] as List)
                                .map((t) => Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(t.toString(),
                                          style:
                                              AppTextStyles.labelSmall
                                                  .copyWith(
                                                      color: AppColors
                                                          .primary)),
                                    ))
                                .toList(),
                          ),
                        const SizedBox(height: 12),

                        Text(p['title'] ?? '',
                            style: AppTextStyles.headlineLarge),
                        const SizedBox(height: 12),

                        // Author + date
                        Row(
                          children: [
                            AppAvatar(
                              imageUrl: author?['avatar_url'],
                              name: author?['full_name'],
                              size: 36,
                              showVerified: true,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(author?['full_name'] ?? 'Author',
                                    style: AppTextStyles.titleSmall),
                                if (p['published_at'] != null)
                                  Text(
                                    timeago.format(DateTime.parse(
                                        p['published_at'])),
                                    style: AppTextStyles.bodySmall,
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(Icons.remove_red_eye_outlined,
                                    size: 14,
                                    color: AppColors.textTertiary),
                                const SizedBox(width: 4),
                                Text('${p['views_count'] ?? 0}',
                                    style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Content
                        Text(p['content'] ?? '',
                            style: AppTextStyles.bodyLarge
                                .copyWith(height: 1.8)),
                        const SizedBox(height: 32),

                        // Comments
                        Text(
                          'Comments (${_comments.length})',
                          style: AppTextStyles.headlineSmall,
                        ),
                        const SizedBox(height: 12),

                        if (_comments.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            child: Text('Be the first to comment!',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary)),
                          ),

                        ..._comments.map((c) => _CommentTile(comment: c)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar — like + comment
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _hasLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _hasLiked
                            ? AppColors.error
                            : AppColors.textTertiary,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text('${p['likes_count'] ?? 0}',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addComment,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isCommenting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final author = comment['users'] as Map<String, dynamic>?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
              imageUrl: author?['avatar_url'],
              name: author?['full_name'],
              size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author?['full_name'] ?? 'User',
                          style: AppTextStyles.titleSmall
                              .copyWith(fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(comment['content'] ?? '',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    timeago
                        .format(DateTime.parse(comment['created_at'])),
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
