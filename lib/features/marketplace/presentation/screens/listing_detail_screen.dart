import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/marketplace_models.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_avatar.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState
    extends ConsumerState<ListingDetailScreen> {
  ListingModel? _listing;
  bool _isLoading = true;
  int _currentImage = 0;
  int _quantity = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('marketplace_listings')
          .select('*, users(full_name, avatar_url, is_verified, region)')
          .eq('id', widget.listingId)
          .single();
      // increment view count
      await SupabaseService.client
          .from('marketplace_listings')
          .update({'views_count': (data['views_count'] as int) + 1})
          .eq('id', widget.listingId);
      setState(() {
        _listing = ListingModel.fromJson(data);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToWishlist() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('saved_listings').upsert({
        'user_id': SupabaseService.currentUserId,
        'listing_id': widget.listingId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to wishlist')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _placeOrder(BuildContext context) {
    if (_listing == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderSheet(listing: _listing!, quantity: _quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_listing == null) {
      return const Scaffold(
          body: Center(child: Text('Listing not found')));
    }

    final l = _listing!;
    final isOwner = l.sellerId == SupabaseService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image carousel app bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.white,
            actions: [
              if (!isOwner)
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: _saveToWishlist,
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  l.hasImages
                      ? PageView.builder(
                          itemCount: l.images.length,
                          onPageChanged: (i) =>
                              setState(() => _currentImage = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: l.images[i],
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.surfaceVariant),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: const Center(
                              child: Text('🌾',
                                  style: TextStyle(fontSize: 64)))),
                  // Dots
                  if (l.images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          l.images.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImage == i ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentImage == i
                                  ? AppColors.primary
                                  : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(l.title,
                            style: AppTextStyles.headlineMedium),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${AppConstants.currencySymbol}${l.priceGhs.toStringAsFixed(2)}',
                            style: AppTextStyles.priceLarge,
                          ),
                          Text('per ${l.unit}',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags row
                  Wrap(
                    spacing: 8,
                    children: [
                      if (l.isNegotiable)
                        _Tag('Negotiable', AppColors.secondary),
                      if (l.deliveryAvailable)
                        _Tag('Delivery Available', AppColors.info),
                      if (l.pickupAvailable)
                        _Tag('Pickup Available', AppColors.primary),
                      _Tag(l.category, AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Availability
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Available: ${l.quantityAvailable.toStringAsFixed(0)} ${l.unit}',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (l.region != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          l.location != null
                              ? '${l.location}, ${l.region}'
                              : l.region!,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Description
                  if (l.description != null && l.description!.isNotEmpty) ...[
                    Text('Description', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Text(l.description!,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary, height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Seller card
                  Text('Seller', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        AppAvatar(
                          imageUrl: l.sellerAvatar,
                          name: l.sellerName,
                          size: 48,
                          showVerified: l.sellerVerified ?? false,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.sellerName ?? 'Seller',
                                  style: AppTextStyles.titleMedium),
                              if (l.sellerVerified == true)
                                Row(
                                  children: [
                                    const Icon(Icons.verified,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text('Verified Seller',
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color: AppColors.primary)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (!isOwner)
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Contact'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // bottom padding for button
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom buy bar
      bottomNavigationBar: isOwner
          ? null
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
              child: Row(
                children: [
                  // Quantity picker
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text('$_quantity',
                            style: AppTextStyles.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _quantity <
                                  l.quantityAvailable.toInt()
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label:
                          'Buy Now — ${AppConstants.currencySymbol}${(l.priceGhs * _quantity).toStringAsFixed(2)}',
                      onPressed: () => _placeOrder(context),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _OrderSheet extends ConsumerStatefulWidget {
  final ListingModel listing;
  final int quantity;
  const _OrderSheet({required this.listing, required this.quantity});

  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  String _paymentMethod = 'wallet';
  bool _isProcessing = false;
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    setState(() => _isProcessing = true);
    try {
      final l = widget.listing;
      final total = l.priceGhs * widget.quantity;
      final platformFee = total * AppConstants.platformMarketplaceFeePercent;

      // Create order
      final order = await SupabaseService.client
          .from('orders')
          .insert({
            'buyer_id': SupabaseService.currentUserId,
            'seller_id': l.sellerId,
            'status': 'pending_payment',
            'subtotal_ghs': total,
            'delivery_fee_ghs': 0,
            'platform_fee_ghs': platformFee,
            'total_ghs': total + platformFee,
            'delivery_address': _addressController.text.trim(),
            'payment_method': _paymentMethod,
          })
          .select()
          .single();

      // Create order item
      await SupabaseService.client.from('order_items').insert({
        'order_id': order['id'],
        'listing_id': l.id,
        'quantity': widget.quantity.toDouble(),
        'unit_price_ghs': l.priceGhs,
        'total_price_ghs': total,
        'snapshot': {
          'title': l.title,
          'images': l.images,
          'unit': l.unit,
        },
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed! Proceed to payment.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/orders/${order['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final total = l.priceGhs * widget.quantity;
    final platformFee = total * AppConstants.platformMarketplaceFeePercent;

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
      child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Confirm Order', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 16),

            // Item summary
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                      child: Text('🌾',
                          style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: AppTextStyles.titleSmall),
                      Text('${widget.quantity} × ${l.unit}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Text(
                  '${AppConstants.currencySymbol}${total.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Delivery address
            if (l.deliveryAvailable) ...[
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Delivery Address (optional)',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Price breakdown
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _Row('Subtotal',
                      '${AppConstants.currencySymbol}${total.toStringAsFixed(2)}'),
                  _Row('Platform fee (2.5%)',
                      '${AppConstants.currencySymbol}${platformFee.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _Row(
                      'Total',
                      '${AppConstants.currencySymbol}${(total + platformFee).toStringAsFixed(2)}',
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment method
            Text('Pay with', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _PayChip('wallet', 'Wallet', Icons.account_balance_wallet_outlined, _paymentMethod,
                    (v) => setState(() => _paymentMethod = v)),
                const SizedBox(width: 8),
                _PayChip('momo', 'MoMo', Icons.phone_android_outlined, _paymentMethod,
                    (v) => setState(() => _paymentMethod = v)),
                const SizedBox(width: 8),
                _PayChip('card', 'Card', Icons.credit_card_outlined, _paymentMethod,
                    (v) => setState(() => _paymentMethod = v)),
              ],
            ),
            const SizedBox(height: 24),

            AppButton(
              label: 'Place Order',
              isLoading: _isProcessing,
              onPressed: _placeOrder,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.bodySmall),
          Text(value,
              style: bold
                  ? AppTextStyles.titleSmall
                      .copyWith(color: AppColors.primary)
                  : AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String selected;
  final void Function(String) onTap;
  const _PayChip(this.value, this.label, this.icon, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
