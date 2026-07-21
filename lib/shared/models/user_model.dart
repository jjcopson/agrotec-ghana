class UserModel {
  final String id;
  final String fullName;
  final String? username;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final List<String> roles;
  final String activeRole;
  final String? region;
  final String? district;
  final bool isVerified;
  final bool isActive;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    this.username,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.bio,
    required this.roles,
    required this.activeRole,
    this.region,
    this.district,
    required this.isVerified,
    required this.isActive,
    this.lastSeenAt,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      username: json['username'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      roles: (json['roles'] as List<dynamic>?)
              ?.map((r) => r.toString())
              .toList() ??
          ['customer'],
      activeRole: json['active_role'] as String? ?? 'customer',
      region: json['region'] as String?,
      district: json['district'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'bio': bio,
      'roles': roles,
      'active_role': activeRole,
      'region': region,
      'district': district,
      'is_verified': isVerified,
      'is_active': isActive,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isFarmer => roles.contains('farmer');
  bool get isExpert => roles.contains('expert');
  bool get isDriver => roles.contains('truck_driver');
  bool get isWholesaler => roles.contains('wholesaler');
  bool get isRetailer => roles.contains('retailer');
  bool get isEnthusiast => roles.contains('enthusiast');
  bool get isCustomer => roles.contains('customer');
  bool get isAdmin => roles.contains('admin');
  bool get isBusiness =>
      roles.contains('processing_industry') ||
      roles.contains('wholesaler') ||
      roles.contains('retailer');

  String get displayName => username ?? fullName;

  UserModel copyWith({
    String? fullName,
    String? username,
    String? phone,
    String? avatarUrl,
    String? bio,
    List<String>? roles,
    String? activeRole,
    String? region,
    String? district,
    bool? isVerified,
    bool? isActive,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      region: region ?? this.region,
      district: district ?? this.district,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      lastSeenAt: lastSeenAt,
      createdAt: createdAt,
    );
  }
}
