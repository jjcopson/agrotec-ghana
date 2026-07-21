class ConsultationModel {
  final String id;
  final String clientId;
  final String expertId;
  final String expertProfileId;
  final String status;
  final String topic;
  final String? description;
  final double sessionPriceGhs;
  final double platformFeeGhs;
  final double expertEarningsGhs;
  final int messageCount;
  final bool isFreeThresholdHit;
  final DateTime? freeEndedAt;
  final DateTime? freeStartAt;
  final DateTime? paidStartAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final String paymentStatus;
  final String? paymentMethod;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  // Joined
  final String? clientName;
  final String? clientAvatar;
  final String? expertName;
  final String? expertAvatar;
  final String? expertLabel;

  const ConsultationModel({
    required this.id,
    required this.clientId,
    required this.expertId,
    required this.expertProfileId,
    required this.status,
    required this.topic,
    this.description,
    required this.sessionPriceGhs,
    required this.platformFeeGhs,
    required this.expertEarningsGhs,
    required this.messageCount,
    required this.isFreeThresholdHit,
    this.freeEndedAt,
    this.freeStartAt,
    this.paidStartAt,
    this.endedAt,
    this.durationMinutes,
    required this.paymentStatus,
    this.paymentMethod,
    this.scheduledAt,
    required this.createdAt,
    this.clientName,
    this.clientAvatar,
    this.expertName,
    this.expertAvatar,
    this.expertLabel,
  });

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    final clientData = json['client'] as Map<String, dynamic>?;
    final expertData = json['expert'] as Map<String, dynamic>?;
    final expertProfile = json['expert_profiles'] as Map<String, dynamic>?;

    return ConsultationModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      expertId: json['expert_id'] as String,
      expertProfileId: json['expert_profile_id'] as String,
      status: json['status'] as String,
      topic: json['topic'] as String,
      description: json['description'] as String?,
      sessionPriceGhs: (json['session_price_ghs'] as num?)?.toDouble() ?? 0,
      platformFeeGhs: (json['platform_fee_ghs'] as num?)?.toDouble() ?? 0,
      expertEarningsGhs:
          (json['expert_earnings_ghs'] as num?)?.toDouble() ?? 0,
      messageCount: json['message_count'] as int? ?? 0,
      isFreeThresholdHit: json['is_free_threshold_hit'] as bool? ?? false,
      freeEndedAt: json['free_ended_at'] != null
          ? DateTime.parse(json['free_ended_at'] as String)
          : null,
      freeStartAt: json['free_start_at'] != null
          ? DateTime.parse(json['free_start_at'] as String)
          : null,
      paidStartAt: json['paid_start_at'] != null
          ? DateTime.parse(json['paid_start_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentMethod: json['payment_method'] as String?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      clientName: clientData?['full_name'] as String?,
      clientAvatar: clientData?['avatar_url'] as String?,
      expertName: expertData?['full_name'] as String?,
      expertAvatar: expertData?['avatar_url'] as String?,
      expertLabel: expertProfile?['label'] as String?,
    );
  }

  bool get isActive => ['in_progress', 'free_threshold_reached', 'paid'].contains(status);
  bool get isPaid => paymentStatus == 'paid';
  bool get needsPayment =>
      isFreeThresholdHit && paymentStatus == 'unpaid' && sessionPriceGhs > 0;
  bool get isCompleted => status == 'completed';

  int get messagesRemaining =>
      isFreeThresholdHit ? 0 : (10 - messageCount).clamp(0, 10);

  Duration? get freeTimeRemaining {
    if (freeStartAt == null || isFreeThresholdHit) return null;
    final elapsed = DateTime.now().difference(freeStartAt!);
    final remaining = const Duration(minutes: 10) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class ConsultationMessageModel {
  final String id;
  final String consultationId;
  final String senderId;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final bool isFree;
  final bool isRead;
  final DateTime createdAt;

  // Joined
  final String? senderName;
  final String? senderAvatar;

  const ConsultationMessageModel({
    required this.id,
    required this.consultationId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.mediaUrl,
    required this.isFree,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory ConsultationMessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['users'] as Map<String, dynamic>?;
    return ConsultationMessageModel(
      id: json['id'] as String,
      consultationId: json['consultation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      isFree: json['is_free'] as bool? ?? true,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: sender?['full_name'] as String?,
      senderAvatar: sender?['avatar_url'] as String?,
    );
  }
}

class ExpertProfileModel {
  final String id;
  final String userId;
  final String label;
  final List<String> specializations;
  final List<String>? qualifications;
  final String? institution;
  final int? yearsExperience;
  final double sessionPriceGhs;
  final List<String>? availableDays;
  final double rating;
  final int totalConsultations;
  final bool isAvailable;
  final String verificationStatus;
  final DateTime? verifiedAt;

  // Joined user
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String? region;

  const ExpertProfileModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.specializations,
    this.qualifications,
    this.institution,
    this.yearsExperience,
    required this.sessionPriceGhs,
    this.availableDays,
    required this.rating,
    required this.totalConsultations,
    required this.isAvailable,
    required this.verificationStatus,
    this.verifiedAt,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.region,
  });

  factory ExpertProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return ExpertProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String? ?? 'expert',
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      qualifications: (json['qualifications'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      institution: json['institution'] as String?,
      yearsExperience: json['years_experience'] as int?,
      sessionPriceGhs:
          (json['session_price_ghs'] as num?)?.toDouble() ?? 0,
      availableDays: (json['available_days'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalConsultations: json['total_consultations'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'pending',
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      fullName: user?['full_name'] as String?,
      avatarUrl: user?['avatar_url'] as String?,
      bio: user?['bio'] as String?,
      region: user?['region'] as String?,
    );
  }

  bool get isVerified => verificationStatus == 'approved';
  String get displayLabel =>
      label[0].toUpperCase() + label.substring(1);
}
