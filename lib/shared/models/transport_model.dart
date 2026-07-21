class TransportJobModel {
  final String id;
  final String posterId;
  final String? assignedDriverId;
  final String status;
  final String title;
  final String? description;
  final String cargoType;
  final double? cargoWeightKg;
  final List<String> cargoImages;
  final String pickupAddress;
  final String pickupRegion;
  final double? pickupLat;
  final double? pickupLng;
  final DateTime pickupDate;
  final String deliveryAddress;
  final String deliveryRegion;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? budgetGhs;
  final double? agreedPriceGhs;
  final String paymentStatus;
  final DateTime? assignedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final int bidsCount;

  // Joined
  final String? posterName;
  final String? posterAvatar;
  final String? driverName;
  final String? driverAvatar;

  const TransportJobModel({
    required this.id,
    required this.posterId,
    this.assignedDriverId,
    required this.status,
    required this.title,
    this.description,
    required this.cargoType,
    this.cargoWeightKg,
    required this.cargoImages,
    required this.pickupAddress,
    required this.pickupRegion,
    this.pickupLat,
    this.pickupLng,
    required this.pickupDate,
    required this.deliveryAddress,
    required this.deliveryRegion,
    this.deliveryLat,
    this.deliveryLng,
    this.budgetGhs,
    this.agreedPriceGhs,
    required this.paymentStatus,
    this.assignedAt,
    this.deliveredAt,
    required this.createdAt,
    required this.bidsCount,
    this.posterName,
    this.posterAvatar,
    this.driverName,
    this.driverAvatar,
  });

  factory TransportJobModel.fromJson(Map<String, dynamic> json) {
    final poster = json['poster'] as Map<String, dynamic>?;
    final driver = json['driver'] as Map<String, dynamic>?;
    return TransportJobModel(
      id: json['id'] as String,
      posterId: json['poster_id'] as String,
      assignedDriverId: json['assigned_driver_id'] as String?,
      status: json['status'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      cargoType: json['cargo_type'] as String,
      cargoWeightKg: (json['cargo_weight_kg'] as num?)?.toDouble(),
      cargoImages: (json['cargo_images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pickupAddress: json['pickup_address'] as String,
      pickupRegion: json['pickup_region'] as String,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      pickupDate: DateTime.parse(json['pickup_date'] as String),
      deliveryAddress: json['delivery_address'] as String,
      deliveryRegion: json['delivery_region'] as String,
      deliveryLat: (json['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (json['delivery_lng'] as num?)?.toDouble(),
      budgetGhs: (json['budget_ghs'] as num?)?.toDouble(),
      agreedPriceGhs: (json['agreed_price_ghs'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      bidsCount: json['bids_count'] as int? ?? 0,
      posterName: poster?['full_name'] as String?,
      posterAvatar: poster?['avatar_url'] as String?,
      driverName: driver?['full_name'] as String?,
      driverAvatar: driver?['avatar_url'] as String?,
    );
  }

  bool get isOpen => status == 'open' || status == 'bidding';
  bool get isAssigned => status == 'assigned';
  bool get isInTransit => status == 'in_transit';
  bool get isDelivered => status == 'delivered';
  bool get isCompleted => status == 'completed';
}

class TransportBidModel {
  final String id;
  final String jobId;
  final String driverId;
  final double bidAmountGhs;
  final String? message;
  final int? estimatedDays;
  final String status;
  final DateTime createdAt;

  // Joined
  final String? driverName;
  final String? driverAvatar;
  final double? driverRating;
  final int? driverTotalTrips;
  final String? vehicleType;

  const TransportBidModel({
    required this.id,
    required this.jobId,
    required this.driverId,
    required this.bidAmountGhs,
    this.message,
    this.estimatedDays,
    required this.status,
    required this.createdAt,
    this.driverName,
    this.driverAvatar,
    this.driverRating,
    this.driverTotalTrips,
    this.vehicleType,
  });

  factory TransportBidModel.fromJson(Map<String, dynamic> json) {
    final driver = json['users'] as Map<String, dynamic>?;
    final driverProfile = json['driver_profiles'] as Map<String, dynamic>?;
    return TransportBidModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      driverId: json['driver_id'] as String,
      bidAmountGhs: (json['bid_amount_ghs'] as num).toDouble(),
      message: json['message'] as String?,
      estimatedDays: json['estimated_days'] as int?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      driverName: driver?['full_name'] as String?,
      driverAvatar: driver?['avatar_url'] as String?,
      driverRating: (driverProfile?['rating'] as num?)?.toDouble(),
      driverTotalTrips: driverProfile?['total_trips'] as int?,
      vehicleType: driverProfile?['vehicle_type'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}
