import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/helpers.dart';
import '../../models/forum_model.dart';
import '../../providers/forum_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/custom_text_field.dart';

class ForumListScreen extends StatefulWidget {
  const ForumListScreen({super.key});

  @override
  State<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends State<ForumListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForumProvider>().loadPosts(refresh: true);
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ForumProvider>().loadPosts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forumProvider = context.watch<ForumProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchTextField(
              controller: _searchController,
              hint: 'Search posts...',
              onChanged: (query) {
                forumProvider.setSearchQuery(query);
              },
              onClear: () {
                _searchController.clear();
                forumProvider.setSearchQuery('');
              },
            ),
          ),
          Expanded(
            child: _buildBody(forumProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'forumFab',
        onPressed: () async {
          await Navigator.pushNamed(context, AppConstants.createPostRoute);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ForumProvider forumProvider) {
    if (forumProvider.isLoading && forumProvider.posts.isEmpty) {
      return const LoadingWidget();
    }

    if (forumProvider.posts.isEmpty) {
      return EmptyStateWidget(
        title: 'No posts yet',
        subtitle: 'Be the first to start a discussion',
        icon: Icons.forum_outlined,
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, AppConstants.createPostRoute);
          },
          icon: const Icon(Icons.add),
          label: const Text('Create Post'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: forumProvider.refreshPosts,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: forumProvider.posts.length + (forumProvider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == forumProvider.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _PostCard(
            post: forumProvider.posts[index],
            onTap: () => _openPost(forumProvider.posts[index]),
          );
        },
      ),
    );
  }

  void _openPost(ForumPostModel post) {
    Navigator.pushNamed(
      context,
      AppConstants.postDetailRoute,
      arguments: post.id,
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterSheet(),
    );
  }
}

class _PostCard extends StatelessWidget {
  final ForumPostModel post;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      post.author?.initials ?? 'U',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author?.displayName ?? 'Unknown',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          Helpers.timeAgo(post.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.category != null)
                    Chip(
                      label: Text(post.category!),
                      labelStyle: const TextStyle(fontSize: 10),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _VoteButton(
                    post: post,
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    icon: Icons.comment_outlined,
                    value: post.commentCount.toString(),
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    icon: Icons.visibility_outlined,
                    value: post.viewCount.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final ForumPostModel post;

  const _VoteButton({
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final isUpvoted = post.userVote == 1;
    final color = isUpvoted 
        ? AppColors.primary 
        : (post.score > 0 ? AppColors.success : AppColors.gray500);

    return InkWell(
      onTap: () async {
        await context.read<ForumProvider>().voteOnPost(post.id, true);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              isUpvoted ? Icons.arrow_upward : Icons.arrow_upward_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              post.score.toString(),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isUpvoted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gray500),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gray500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FilterSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'General', 'Questions', 'Discussion', 'Announcements'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: categories.map((category) {
              return FilterChip(
                label: Text(category),
                selected: context.watch<ForumProvider>().selectedCategory ==
                    (category == 'All' ? null : category),
                onSelected: (selected) {
                  context.read<ForumProvider>().setCategory(
                    selected && category != 'All' ? category : null,
                  );
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
