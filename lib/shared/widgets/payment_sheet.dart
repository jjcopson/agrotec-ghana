import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/payment_service.dart';

/// Universal payment sheet — used for wallet top-up, orders, consultations
class PaymentSheet extends StatefulWidget {
  final double amountGhs;
  final String title;
  final String subtitle;
  final double? walletBalance;
  final Future<void> Function(PaymentMethod method, String? momoNumber) onPay;

  const PaymentSheet({
    super.key,
    required this.amountGhs,
    required this.title,
    required this.subtitle,
    required this.onPay,
    this.walletBalance,
  });

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  PaymentMethod _selected = PaymentMethod.momoMTN;
  final _momoController = TextEditingController();
  bool _isProcessing = false;
  String? _momoError;

  @override
  void dispose() {
    _momoController.dispose();
    super.dispose();
  }

  bool get _canUseWallet =>
      widget.walletBalance != null &&
      widget.walletBalance! >= widget.amountGhs;

  Future<void> _pay() async {
    // Validate MoMo number
    if (_selected.isMomo) {
      final num = _momoController.text.trim();
      if (num.isEmpty || num.length < 10) {
        setState(() => _momoError = 'Enter a valid 10-digit MoMo number');
        return;
      }
      setState(() => _momoError = null);
    }

    setState(() => _isProcessing = true);
    try {
      await widget.onPay(
        _selected,
        _selected.isMomo ? _momoController.text.trim() : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(widget.title, style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(widget.subtitle,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount to pay',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  Text(
                    '₵${widget.amountGhs.toStringAsFixed(2)}',
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Choose payment method',
                style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),

            // Payment method options
            if (_canUseWallet)
              _MethodTile(
                method: PaymentMethod.wallet,
                selected: _selected,
                subtitle:
                    'Balance: ₵${widget.walletBalance!.toStringAsFixed(2)}',
                onTap: () => setState(() => _selected = PaymentMethod.wallet),
              ),

            _MethodTile(
              method: PaymentMethod.momoMTN,
              selected: _selected,
              subtitle: 'Receive USSD prompt on your MTN number',
              onTap: () => setState(() => _selected = PaymentMethod.momoMTN),
            ),

            _MethodTile(
              method: PaymentMethod.momoVodafone,
              selected: _selected,
              subtitle: 'Receive USSD prompt on your Vodafone number',
              onTap: () =>
                  setState(() => _selected = PaymentMethod.momoVodafone),
            ),

            _MethodTile(
              method: PaymentMethod.momoAirtelTigo,
              selected: _selected,
              subtitle: 'Receive USSD prompt on your AirtelTigo number',
              onTap: () =>
                  setState(() => _selected = PaymentMethod.momoAirtelTigo),
            ),

            _MethodTile(
              method: PaymentMethod.card,
              selected: _selected,
              subtitle: 'Visa, Mastercard, Verve',
              onTap: () => setState(() => _selected = PaymentMethod.card),
            ),

            _MethodTile(
              method: PaymentMethod.bankTransfer,
              selected: _selected,
              subtitle: 'Transfer directly from your bank',
              onTap: () =>
                  setState(() => _selected = PaymentMethod.bankTransfer),
            ),

            // MoMo number input — shown when MoMo selected
            if (_selected.isMomo) ...[
              const SizedBox(height: 16),
              Text('${_selected.label} Number',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _momoController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '0241234567',
                  errorText: _momoError,
                  prefixText: '+233 ',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '⚡ You will receive a prompt on this number to approve payment',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.success),
              ),
            ],

            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _selected == PaymentMethod.wallet
                            ? 'Pay from Wallet'
                            : _selected.isMomo
                                ? 'Send MoMo Prompt'
                                : 'Continue to Pay',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Security note
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('Secured by Paystack',
                      style: AppTextStyles.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final PaymentMethod selected;
  final String subtitle;
  final VoidCallback onTap;

  const _MethodTile({
    required this.method,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(method.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label, style: AppTextStyles.titleSmall),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to show the payment sheet from anywhere
Future<bool?> showPaymentSheet({
  required BuildContext context,
  required double amountGhs,
  required String title,
  required String subtitle,
  double? walletBalance,
  required Future<void> Function(PaymentMethod method, String? momoNumber) onPay,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PaymentSheet(
      amountGhs: amountGhs,
      title: title,
      subtitle: subtitle,
      walletBalance: walletBalance,
      onPay: onPay,
    ),
  );
}
