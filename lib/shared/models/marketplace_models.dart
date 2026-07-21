class ListingModel {
  final String id;
  final String sellerId;
  final String title;
  final String? description;
  final String category;
  final String? subcategory;
  final double priceGhs;
  final String unit;
  final double quantity;
  final double quantityAvailable;
  final List<String> images;
  final String? location;
  final String? region;
  final String? district;
  final double? lat;
  final double? lng;
  final List<String> tags;
  final String status;
  final int viewsCount;
  final bool isNegotiable;
  final bool deliveryAvailable;
  final bool pickupAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined seller info
  final String? sellerName;
  final String? sellerAvatar;
  final bool? sellerVerified;

  const ListingModel({
    required this.id,
    required this.sellerId,
    required this.title,
    this.description,
    required this.category,
    this.subcategory,
    required this.priceGhs,
    required this.unit,
    required this.quantity,
    required this.quantityAvailable,
    required this.images,
    this.location,
    this.region,
    this.district,
    this.lat,
    this.lng,
    required this.tags,
    required this.status,
    required this.viewsCount,
    required this.isNegotiable,
    required this.deliveryAvailable,
    required this.pickupAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.sellerName,
    this.sellerAvatar,
    this.sellerVerified,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    final seller = json['users'] as Map<String, dynamic>?;
    return ListingModel(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      priceGhs: (json['price_ghs'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      quantity: (json['quantity'] as num).toDouble(),
      quantityAvailable: (json['quantity_available'] as num).toDouble(),
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      location: json['location'] as String?,
      region: json['region'] as String?,
      district: json['district'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'active',
      viewsCount: json['views_count'] as int? ?? 0,
      isNegotiable: json['is_negotiable'] as bool? ?? false,
      deliveryAvailable: json['delivery_available'] as bool? ?? false,
      pickupAvailable: json['pickup_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // seller info optional - only present when joined
      sellerName: seller?['full_name'] as String?,
      sellerAvatar: seller?['avatar_url'] as String?,
      sellerVerified: seller?['is_verified'] as bool?,
    );
  }

  String get thumbnailUrl => images.isNotEmpty ? images.first : '';
  bool get hasImages => images.isNotEmpty;
  bool get isAvailable => quantityAvailable > 0 && status == 'active';
}

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String status;
  final double subtotalGhs;
  final double deliveryFeeGhs;
  final double platformFeeGhs;
  final double totalGhs;
  final String? deliveryAddress;
  final String? notes;
  final String? paymentMethod;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  // Escrow
  final EscrowModel? escrow;

  const OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.subtotalGhs,
    required this.deliveryFeeGhs,
    required this.platformFeeGhs,
    required this.totalGhs,
    this.deliveryAddress,
    this.notes,
    this.paymentMethod,
    this.deliveredAt,
    this.completedAt,
    required this.createdAt,
    required this.items,
    this.escrow,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      status: json['status'] as String,
      subtotalGhs: (json['subtotal_ghs'] as num).toDouble(),
      deliveryFeeGhs: (json['delivery_fee_ghs'] as num?)?.toDouble() ?? 0,
      platformFeeGhs: (json['platform_fee_ghs'] as num?)?.toDouble() ?? 0,
      totalGhs: (json['total_ghs'] as num).toDouble(),
      deliveryAddress: json['delivery_address'] as String?,
      notes: json['notes'] as String?,
      paymentMethod: json['payment_method'] as String?,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: (json['order_items'] as List<dynamic>?)
              ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      escrow: json['escrow_records'] != null
          ? EscrowModel.fromJson(json['escrow_records'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending => status == 'pending_payment';
  bool get isPaid => ['paid', 'processing', 'shipped', 'delivered'].contains(status);
  bool get isCompleted => status == 'completed';
  bool get isDisputed => status == 'disputed';
  bool get canConfirmDelivery => status == 'delivered';
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String listingId;
  final double quantity;
  final double unitPriceGhs;
  final double totalPriceGhs;
  final Map<String, dynamic>? snapshot;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.listingId,
    required this.quantity,
    required this.unitPriceGhs,
    required this.totalPriceGhs,
    this.snapshot,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      listingId: json['listing_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPriceGhs: (json['unit_price_ghs'] as num).toDouble(),
      totalPriceGhs: (json['total_price_ghs'] as num).toDouble(),
      snapshot: json['snapshot'] as Map<String, dynamic>?,
    );
  }

  String? get snapshotTitle => snapshot?['title'] as String?;
  String? get snapshotImage =>
      (snapshot?['images'] as List?)?.firstOrNull as String?;
}

class EscrowModel {
  final String id;
  final String orderId;
  final String buyerId;
  final String sellerId;
  final double amountGhs;
  final double platformFeeGhs;
  final String status;
  final DateTime heldAt;
  final DateTime autoReleaseAt;
  final DateTime? releasedAt;
  final String? releaseTriggeredBy;

  const EscrowModel({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.sellerId,
    required this.amountGhs,
    required this.platformFeeGhs,
    required this.status,
    required this.heldAt,
    required this.autoReleaseAt,
    this.releasedAt,
    this.releaseTriggeredBy,
  });

  factory EscrowModel.fromJson(Map<String, dynamic> json) {
    return EscrowModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      amountGhs: (json['amount_ghs'] as num).toDouble(),
      platformFeeGhs: (json['platform_fee_ghs'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String,
      heldAt: DateTime.parse(json['held_at'] as String),
      autoReleaseAt: DateTime.parse(json['auto_release_at'] as String),
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String)
          : null,
      releaseTriggeredBy: json['release_triggered_by'] as String?,
    );
  }

  bool get isHeld => status == 'held';
  bool get isReleased => status == 'released';

  Duration get timeUntilAutoRelease =>
      autoReleaseAt.difference(DateTime.now());
}
