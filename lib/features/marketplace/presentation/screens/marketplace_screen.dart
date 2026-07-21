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

// ── Category definitions ────────────────────────────────────────────────────
const _categories = [
  ('all', 'All', '🛒'),
  ('crops', 'Crops', '🌾'),
  ('livestock', 'Livestock', '🐄'),
  ('equipment', 'Equipment', '🚜'),
  ('inputs', 'Inputs', '🌱'),
  ('processed_goods', 'Processed', '📦'),
  ('seeds', 'Seeds', '🫘'),
  ('fertilizers', 'Fertilizers', '🧪'),
];

// ── Marketplace Screen ───────────────────────────────────────────────────────
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _selectedCategory = 'all';
  String _selectedRegion = '';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<ListingModel> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Simple direct Supabase query — no chaining after order/limit
      final data = await SupabaseService.client
          .from('marketplace_listings')
          .select(
              'id, seller_id, title, description, category, price_ghs, unit, '
              'quantity, quantity_available, images, location, region, status, '
              'views_count, is_negotiable, delivery_available, pickup_available, '
              'created_at, updated_at, tags')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);

      final all = (data as List)
          .map((e) => ListingModel.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _listings = all;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Filter listings client-side
  List<ListingModel> get _filtered {
    return _listings.where((l) {
      if (_selectedCategory != 'all' && l.category != _selectedCategory) {
        return false;
      }
      if (_selectedRegion.isNotEmpty && l.region != _selectedRegion) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !l.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final isSeller = user != null &&
        user.isVerified &&
        (user.isFarmer ||
            user.isRetailer ||
            user.isWholesaler ||
            user.isBusiness);

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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadListings,
          ),
        ],
      ),
      floatingActionButton: isSeller
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppConstants.routeCreateListing),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Sell',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
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

          // Region chip
          if (_selectedRegion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Loading listings...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Could not load listings',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadListings,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final listings = _filtered;

    if (listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                _listings.isEmpty
                    ? 'No listings yet'
                    : 'No results found',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _listings.isEmpty
                    ? 'Be the first to list a product!'
                    : 'Try a different category or search term.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (_listings.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedCategory = 'all';
                    _selectedRegion = '';
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: listings.length,
        itemBuilder: (_, i) => _ListingCard(
          listing: listings[i],
          onTap: () =>
              context.go('/marketplace/listing/${listings[i].id}'),
        ),
      ),
    );
  }

  void _showRegionFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Text('Filter by Region',
                style: AppTextStyles.headlineSmall),
          ),
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

// ── Listing Card ─────────────────────────────────────────────────────────────
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                        placeholder: (_, __) =>
                            Container(color: AppColors.surfaceVariant),
                        errorWidget: (_, __, ___) =>
                            _PlaceholderImg(listing.category),
                      )
                    : _PlaceholderImg(listing.category),
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${AppConstants.currencySymbol}${listing.priceGhs.toStringAsFixed(2)}',
                        style: AppTextStyles.priceText.copyWith(fontSize: 15),
                      ),
                      Text('/${listing.unit}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (listing.region != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 10, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            listing.region!,
                            style: AppTextStyles.labelSmall
                                .copyWith(fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (listing.isNegotiable)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImg extends StatelessWidget {
  final String category;
  const _PlaceholderImg(this.category);

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
