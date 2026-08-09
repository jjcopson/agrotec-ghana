import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';
import '../constants/app_constants.dart';

// ── Payment Method Enum ──────────────────────────────────────────────────────

enum PaymentMethod {
  wallet,
  momoMTN,
  momoVodafone,
  momoAirtelTigo,
  card,
  bankTransfer,
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.wallet: return 'Wallet';
      case PaymentMethod.momoMTN: return 'MTN MoMo';
      case PaymentMethod.momoVodafone: return 'Vodafone Cash';
      case PaymentMethod.momoAirtelTigo: return 'AirtelTigo Money';
      case PaymentMethod.card: return 'Debit/Credit Card';
      case PaymentMethod.bankTransfer: return 'Bank Transfer';
    }
  }

  String get icon {
    switch (this) {
      case PaymentMethod.wallet: return '💰';
      case PaymentMethod.momoMTN: return '📱';
      case PaymentMethod.momoVodafone: return '📱';
      case PaymentMethod.momoAirtelTigo: return '📱';
      case PaymentMethod.card: return '💳';
      case PaymentMethod.bankTransfer: return '🏦';
    }
  }

  bool get isMomo =>
      this == PaymentMethod.momoMTN ||
      this == PaymentMethod.momoVodafone ||
      this == PaymentMethod.momoAirtelTigo;

  String get paystackChannel {
    if (isMomo) return 'mobile_money';
    if (this == PaymentMethod.card) return 'card';
    if (this == PaymentMethod.bankTransfer) return 'bank_transfer';
    return 'wallet';
  }

  String get momoProvider {
    switch (this) {
      case PaymentMethod.momoMTN: return 'mtn';
      case PaymentMethod.momoVodafone: return 'vod';
      case PaymentMethod.momoAirtelTigo: return 'tgo';
      default: return '';
    }
  }
}

// ── Payment Result ───────────────────────────────────────────────────────────

class PaymentResult {
  final bool success;
  final String reference;
  final String? message;
  final String? authorizationUrl;

  const PaymentResult({
    required this.success,
    required this.reference,
    this.message,
    this.authorizationUrl,
  });
}

// ── Payment Service ──────────────────────────────────────────────────────────

class PaymentService {
  /// No-op initializer kept for backward compatibility
  static Future<void> initialize() async {}

  /// Initialize a payment via Supabase edge function → Paystack
  static Future<PaymentResult> initializePayment({
    required BuildContext context,
    required String email,
    required double amountGhs,
    required PaymentMethod method,
    required Map<String, dynamic> metadata,
    String? momoNumber,
  }) async {
    final reference = const Uuid().v4();
    try {
      final body = <String, dynamic>{
        'email': email,
        'amount': (amountGhs * 100).toInt(),
        'currency': 'GHS',
        'reference': reference,
        'metadata': {
          ...metadata,
          'payment_type': metadata['payment_type'] ?? 'wallet_topup',
        },
        'payment_method': method.paystackChannel,
      };

      if (method.isMomo && momoNumber != null) {
        body['momo_number'] = momoNumber;
        body['momo_network'] = method.momoProvider;
      }

      final response = await SupabaseService.client.functions.invoke(
        'initialize-payment',
        body: body,
      );

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        return PaymentResult(
            success: false,
            reference: reference,
            message: data['error'].toString());
      }

      final authUrl = data['authorization_url'] as String?;

      if (method.isMomo && context.mounted) {
        _showMoMoDialog(context, momoNumber ?? '', method);
      }

      if ((method == PaymentMethod.card ||
              method == PaymentMethod.bankTransfer) &&
          authUrl != null) {
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      return PaymentResult(
          success: true, reference: reference, authorizationUrl: authUrl);
    } catch (e) {
      return PaymentResult(
          success: false, reference: reference, message: e.toString());
    }
  }

  static void _showMoMoDialog(
      BuildContext context, String phone, PaymentMethod method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _MoMoWaitingDialog(phone: phone, network: method.label),
    );
  }

  /// Top up wallet
  static Future<void> topUpWallet({
    required BuildContext context,
    required String userId,
    required String email,
    required double amountGhs,
    required PaymentMethod method,
    String? momoNumber,
  }) async {
    await initializePayment(
      context: context,
      email: email,
      amountGhs: amountGhs,
      method: method,
      momoNumber: momoNumber,
      metadata: {'payment_type': 'wallet_topup', 'user_id': userId},
    );
  }

  /// Release escrow (buyer confirms delivery)
  static Future<void> releaseEscrow({
    required String orderId,
    required String triggeredBy,
  }) async {
    await SupabaseService.client.functions.invoke(
      'release-escrow',
      body: {'order_id': orderId, 'triggered_by': triggeredBy},
    );
  }

  /// Pay for marketplace order
  static Future<PaymentResult> payForOrder({
    required BuildContext context,
    required String orderId,
    required String buyerId,
    required String sellerId,
    required String email,
    required double amountGhs,
    required PaymentMethod method,
    String? momoNumber,
  }) async {
    if (method == PaymentMethod.wallet) {
      await SupabaseService.client.functions.invoke(
        'process-marketplace-payment',
        body: {
          'order_id': orderId,
          'buyer_id': buyerId,
          'seller_id': sellerId,
          'amount_ghs': amountGhs,
          'payment_method': 'wallet',
        },
      );
      return PaymentResult(success: true, reference: orderId);
    }
    return initializePayment(
      context: context,
      email: email,
      amountGhs: amountGhs,
      method: method,
      momoNumber: momoNumber,
      metadata: {
        'payment_type': 'order_payment',
        'order_id': orderId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
      },
    );
  }

  /// Pay for consultation
  static Future<PaymentResult> payForConsultation({
    required BuildContext context,
    required String consultationId,
    required String clientId,
    required String expertId,
    required String email,
    required double amountGhs,
    required PaymentMethod method,
    String? momoNumber,
  }) async {
    if (method == PaymentMethod.wallet) {
      await SupabaseService.client.functions.invoke(
        'process-consultation-payment',
        body: {
          'consultation_id': consultationId,
          'client_id': clientId,
          'expert_id': expertId,
          'session_price_ghs': amountGhs,
          'payment_method': 'wallet',
        },
      );
      return PaymentResult(success: true, reference: consultationId);
    }
    return initializePayment(
      context: context,
      email: email,
      amountGhs: amountGhs,
      method: method,
      momoNumber: momoNumber,
      metadata: {
        'payment_type': 'consultation_payment',
        'consultation_id': consultationId,
        'client_id': clientId,
        'expert_id': expertId,
      },
    );
  }

  /// Withdraw from wallet to MoMo
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

  static String formatGhs(double amount) =>
      '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
}

// ── MoMo Waiting Dialog ──────────────────────────────────────────────────────

class _MoMoWaitingDialog extends StatelessWidget {
  final String phone;
  final String network;
  const _MoMoWaitingDialog({required this.phone, required this.network});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFC107), width: 2),
            ),
            child: const Center(
                child: Text('📱', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 20),
          const Text('Check your phone',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Text(
            'A payment prompt has been sent to\n$phone',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Approve the $network prompt on your phone to complete payment.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF795548)),
            ),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(Color(0xFF0D9488)),
          ),
          const SizedBox(height: 16),
          const Text('Waiting for confirmation...',
              style: TextStyle(fontSize: 12, color: Colors.black38)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("I've approved — Close"),
          ),
        ],
      ),
    );
  }
}
