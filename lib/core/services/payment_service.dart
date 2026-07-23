import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';
import '../constants/app_constants.dart';

/// All payment methods supported
enum PaymentMethod { wallet, momoMTN, momoVodafone, momoAirtelTigo, card, bankTransfer }

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

class PaymentService {
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
        'amount': (amountGhs * 100).toInt(), // pesewas
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
          message: data['error'].toString(),
        );
      }

      final authUrl = data['authorization_url'] as String?;

      // For MoMo — show waiting dialog (user gets USSD prompt on phone)
      if (method.isMomo && context.mounted) {
        _showMoMoWaitingDialog(context, momoNumber ?? '', method);
      }

      // For card/bank — open Paystack URL
      if ((method == PaymentMethod.card || method == PaymentMethod.bankTransfer) &&
          authUrl != null) {
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      return PaymentResult(
        success: true,
        reference: reference,
        authorizationUrl: authUrl,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        reference: reference,
        message: e.toString(),
      );
    }
  }

  /// Show MoMo waiting dialog
  static void _showMoMoWaitingDialog(
    BuildContext context,
    String phone,
    PaymentMethod method,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MoMoWaitingDialog(
        phone: phone,
        network: method.label,
      ),
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
    if (method == PaymentMethod.wallet) {
      throw Exception('Cannot top up wallet from wallet');
    }

    await initializePayment(
      context: context,
      email: email,
      amountGhs: amountGhs,
      method: method,
      momoNumber: momoNumber,
      metadata: {
        'payment_type': 'wallet_topup',
        'user_id': userId,
      },
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
      // Deduct from wallet directly
      final response = await SupabaseService.client.functions.invoke(
        'process-marketplace-payment',
        body: {
          'order_id': orderId,
          'buyer_id': buyerId,
          'seller_id': sellerId,
          'amount_ghs': amountGhs,
          'payment_method': 'wallet',
        },
      );
      return PaymentResult(
        success: true,
        reference: orderId,
      );
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

  static String formatGhs(double amount) =>
      '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
}

/// MoMo waiting dialog shown while user approves on their phone
class _MoMoWaitingDialog extends StatefulWidget {
  final String phone;
  final String network;

  const _MoMoWaitingDialog({required this.phone, required this.network});

  @override
  State<_MoMoWaitingDialog> createState() => _MoMoWaitingDialogState();
}

class _MoMoWaitingDialogState extends State<_MoMoWaitingDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Animated phone icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFFFC107), width: 2),
            ),
            child: const Center(
              child: Text('📱', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Check your phone',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A payment prompt has been sent to\n${widget.phone}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Approve the ${widget.network} prompt on your phone to complete payment.',
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
          const Text(
            'Waiting for confirmation...',
            style: TextStyle(fontSize: 12, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I\'ve approved — Close'),
          ),
        ],
      ),
    );
  }
}
