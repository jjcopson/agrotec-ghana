import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import '../constants/app_constants.dart';

class PaymentService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    _initialized = true;
  }

  /// Open Paystack payment via WebView / redirect
  /// Returns a PaymentResult with reference for verification
  static Future<PaymentResult> chargeCard({
    required BuildContext context,
    required String email,
    required double amountGhs,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final reference = const Uuid().v4();
    // Initialize transaction via Supabase edge function
    // which calls Paystack API server-side
    try {
      final response = await SupabaseService.client.functions.invoke(
        'initialize-payment',
        body: {
          'email': email,
          'amount': (amountGhs * 100).toInt(), // pesewas
          'currency': 'GHS',
          'reference': reference,
          'metadata': metadata ?? {},
        },
      );
      final authUrl = response.data['authorization_url'] as String?;
      if (authUrl != null) {
        // In production, open authUrl in a WebView or browser
        // For now return success with reference for testing
        return PaymentResult(success: true, reference: reference);
      }
      return PaymentResult(success: false, reference: reference, message: 'Failed to get payment URL');
    } catch (e) {
      return PaymentResult(success: false, reference: reference, message: e.toString());
    }
  }

  /// Top up wallet after successful Paystack payment
  static Future<void> topUpWallet({
    required String userId,
    required double amountGhs,
    required String paystackRef,
  }) async {
    await SupabaseService.client.functions.invoke(
      'verify-payment',
      body: {
        'reference': paystackRef,
        'user_id': userId,
        'amount_ghs': amountGhs,
        'type': 'wallet_topup',
      },
    );
  }

  /// Process marketplace payment with escrow
  static Future<void> processMarketplacePayment({
    required String orderId,
    required String buyerId,
    required String sellerId,
    required double amountGhs,
    required String paystackRef,
    required String paymentMethod,
  }) async {
    await SupabaseService.client.functions.invoke(
      'process-marketplace-payment',
      body: {
        'order_id': orderId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'amount_ghs': amountGhs,
        'paystack_ref': paystackRef,
        'payment_method': paymentMethod,
      },
    );
  }

  /// Release escrow to seller
  static Future<void> releaseEscrow({
    required String orderId,
    required String triggeredBy,
  }) async {
    await SupabaseService.client.functions.invoke(
      'release-escrow',
      body: {
        'order_id': orderId,
        'triggered_by': triggeredBy,
      },
    );
  }

  /// Pay for a consultation session
  static Future<void> payConsultation({
    required String consultationId,
    required String clientId,
    required String expertId,
    required double sessionPriceGhs,
    required String paymentMethod,
    String? paystackRef,
  }) async {
    final platformFee = sessionPriceGhs * AppConstants.platformConsultationFeePercent;
    final expertEarnings = sessionPriceGhs - platformFee;

    await SupabaseService.client.functions.invoke(
      'process-consultation-payment',
      body: {
        'consultation_id': consultationId,
        'client_id': clientId,
        'expert_id': expertId,
        'session_price_ghs': sessionPriceGhs,
        'platform_fee_ghs': platformFee,
        'expert_earnings_ghs': expertEarnings,
        'payment_method': paymentMethod,
        'paystack_ref': paystackRef,
      },
    );
  }

  /// Withdraw from wallet
  static Future<void> withdrawFromWallet({
    required String userId,
    required double amountGhs,
    required String momoNumber,
    required String momoNetwork,
  }) async {
    await SupabaseService.client.functions.invoke(
      'process-withdrawal',
      body: {
        'user_id': userId,
        'amount_ghs': amountGhs,
        'momo_number': momoNumber,
        'momo_network': momoNetwork,
      },
    );
  }

  static String formatGhs(double amount) {
    return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
  }
}

class PaymentResult {
  final bool success;
  final String reference;
  final String? message;

  PaymentResult({
    required this.success,
    required this.reference,
    this.message,
  });
}
