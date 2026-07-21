import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/marketplace_models.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../features/auth/providers/auth_provider.dart';

final _categories = [
  ('all', 'All', '🛒'),
  ('crops', 'Crops', '🌾'),
  ('livestock', 'Livestock', '🐄'),
  ('equipment', 'Equipment', '🚜'),
  ('inputs', 'Inputs', '🌱'),
  ('processed_goods', 'Processed', '📦'),
  ('seeds', 'Seeds', '🫘'),
  ('fertilizers', 'Fertilizers', '🧪'),
];

final _listingsProvider =
    FutureProvider.family<List<ListingModel>, Map<String, String>>(
        (ref, filters) async {
  // Build filter list first, then apply order/limit
  final category = filters['category'];
  final region = filters['region'];
  final search = filters['search'];

  dynamic query = SupabaseService.client
      .from('marketplace_listings')
      .select('*, users(full_name, avatar_url, is_verified)')
      .eq('status', 'active');

  if (category != null && category != 'all') {
    query = (query as dynamic).eq('category', category);
  }
  if (region != null && region.isNotEmpty) {
    query = (query as dynamic).eq('region', region);
  }
  if (search != null && search.isNotEmpty) {
    query = (query as dynamic).ilike('title', '%$search%');
  }

  final data = await (query as dynamic)
      .order('created_at', ascending: false)
      .limit(AppConstants.defaultPageSize);

  return (data as List).map((e) => ListingModel.fromJson(e)).toList();
});

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _selectedCategory = 'all';
  String _selectedRegion = '';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> get _filters => {
        'category': _selectedCategory,
        'region': _selectedRegion,
        'search': _searchQuery,
      };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final isSeller = user != null &&
        (user.isFarmer ||
            user.isRetailer ||
            user.isWholesaler ||
            user.isBusiness);
    final listingsAsync = ref.watch(_listingsProvider(_filters));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => _showRegionFilter(context),
          ),
        ],
      ),
      floatingActionButton: isSeller
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/marketplace/create'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Sell',
                  style:
                      AppTextStyles.labelLarge.copyWith(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search produce, equipment...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
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

          // Category chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat.$1;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.$3,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          cat.$2,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Region filter chip (if active)
          if (_selectedRegion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(_selectedRegion,
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary)),
                    deleteIcon: const Icon(Icons.close,
                        size: 14, color: AppColors.primary),
                    onDeleted: () =>
                        setState(() => _selectedRegion = ''),
                    backgroundColor: AppColors.primarySurface,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),

          // Listings grid
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (listings) {
                if (listings.isEmpty) {
                  return _EmptyState(
                    category: _selectedCategory,
                    onClear: () => setState(() {
                      _selectedCategory = 'all';
                      _selectedRegion = '';
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (context, i) => _ListingCard(
                    listing: listings[i],
                    onTap: () => context
                        .go('/marketplace/listing/${listings[i].id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRegionFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text('Filter by Region',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('All Regions'),
            leading: Radio<String>(
              value: '',
              groupValue: _selectedRegion,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() => _selectedRegion = v!);
                Navigator.pop(context);
              },
            ),
          ),
          ...AppConstants.ghanaRegions.map((r) => ListTile(
                title: Text(r),
                leading: Radio<String>(
                  value: r,
                  groupValue: _selectedRegion,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _selectedRegion = v!);
                    Navigator.pop(context);
                  },
                ),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: listing.hasImages
                    ? CachedNetworkImage(
                        imageUrl: listing.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: AppColors.surfaceVariant),
                        errorWidget: (_, __, ___) =>
                            _PlaceholderImage(category: listing.category),
                      )
                    : _PlaceholderImage(category: listing.category),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: AppTextStyles.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${AppConstants.currencySymbol}${listing.priceGhs.toStringAsFixed(2)}',
                        style: AppTextStyles.priceText.copyWith(
                            fontSize: 15),
                      ),
                      Text(
                        '/${listing.unit}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AppAvatar(
                        imageUrl: listing.sellerAvatar,
                        name: listing.sellerName,
                        size: 16,
                        showVerified: listing.sellerVerified ?? false,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.sellerName ?? 'Seller',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (listing.region != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 10,
                            color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          listing.region!,
                          style: AppTextStyles.labelSmall
                              .copyWith(fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                  if (listing.isNegotiable) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Negotiable',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  final String category;
  const _PlaceholderImage({required this.category});

  @override
  Widget build(BuildContext context) {
    const emojis = {
      'crops': '🌾',
      'livestock': '🐄',
      'equipment': '🚜',
      'inputs': '🌱',
      'processed_goods': '📦',
      'seeds': '🫘',
      'fertilizers': '🧪',
    };
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Text(
          emojis[category] ?? '🛒',
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String category;
  final VoidCallback onClear;
  const _EmptyState({required this.category, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No listings found',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Try a different category or region.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
