// ignore_for_file: constant_identifier_names

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Agrotech Ghana';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Connecting Ghana\'s Agricultural Future';

  // Supabase
  static const String supabaseUrl = 'https://dzavfprgmnwdxzyjxivq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6YXZmcHJnbW53ZHh6eWp4aXZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwMzIxMTQsImV4cCI6MjA5OTYwODExNH0.E2zjYQYtdVxdvX9hyK3TCG8Oo2PCwgr639-y9FvknI0';

  // Paystack
  static const String paystackPublicKey = 'pk_test_7c29dafd31ebed62bf0aec073fef20c81d883623';

  // Arkesel SMS — replace with your actual key
  static const String arkeselApiKey = 'YOUR_ARKESEL_API_KEY';
  static const String arkeselSenderId = 'AgroGhana';

  // Platform fees
  static const double platformConsultationFeePercent = 0.05; // 5%
  static const double platformMarketplaceFeePercent = 0.025; // 2.5%
  static const double platformTransportFeePercent = 0.05;   // 5%

  // Consultation thresholds
  static const int consultationFreeMessages = 10;
  static const int consultationFreeMinutes = 10;

  // Escrow
  static const int escrowAutoReleaseDays = 3;

  // Pagination
  static const int defaultPageSize = 20;

  // Currency
  static const String currency = 'GHS';
  static const String currencySymbol = '₵';

  // Ghana regions
  static const List<String> ghanaRegions = [
    'Greater Accra',
    'Ashanti',
    'Western',
    'Eastern',
    'Central',
    'Northern',
    'Upper East',
    'Upper West',
    'Volta',
    'Brong-Ahafo',
    'Western North',
    'Ahafo',
    'Bono',
    'Bono East',
    'Oti',
    'Savannah',
    'North East',
  ];

  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String listingImagesBucket = 'listing-images';
  static const String verificationDocsBucket = 'verification-docs';
  static const String courseMediaBucket = 'course-media';
  static const String knowledgeMediaBucket = 'knowledge-media';
  static const String chatMediaBucket = 'chat-media';

  // Route names
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeRoleSelect = '/role-select';
  static const String routeHome = '/home';
  static const String routeMarketplace = '/marketplace';
  static const String routeCreateListing = '/marketplace/create';
  static const String routeListingDetail = '/marketplace/listing/:id';
  static const String routeOrders = '/orders';
  static const String routeOrderDetail = '/orders/:id';
  static const String routeConsultation = '/consultation';
  static const String routeConsultationRoom = '/experts/consultation/:id';
  static const String routeExperts = '/experts';
  static const String routeExpertProfile = '/experts/:id';
  static const String routeTransport = '/transport';
  static const String routeCreateTransportJob = '/transport/create';
  static const String routeTransportJobDetail = '/transport/:id';
  static const String routeKnowledge = '/knowledge';
  static const String routeKnowledgePost = '/knowledge/post/:id';
  static const String routeCourses = '/knowledge/courses';
  static const String routeCourseDetail = '/knowledge/courses/:id';
  static const String routeWallet = '/wallet';
  static const String routeProfile = '/profile';
  static const String routeNotifications = '/notifications';
  static const String routeSettings = '/settings';
  static const String routeVerification = '/verification';
  static const String routeAdmin = '/admin';
}
