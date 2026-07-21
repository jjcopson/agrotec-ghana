import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId!;
    try {
      final wallet = await SupabaseService.client
          .from('wallets')
          .select()
          .eq('user_id', uid)
          .single();

      final txns = await SupabaseService.client
          .from('wallet_transactions')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _wallet = wallet;
        _transactions = List<Map<String, dynamic>>.from(txns as List);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showTopUp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(onSuccess: _load),
    );
  }

  void _showWithdraw() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(
        balance: (_wallet?['balance_ghs'] as num?)?.toDouble() ?? 0,
        onSuccess: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = (_wallet?['balance_ghs'] as num?)?.toDouble() ?? 0.0;
    final escrow = (_wallet?['escrow_balance'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            icon: Icon(
              _balanceVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                setState(() => _balanceVisible = !_balanceVisible),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Balance card
                    Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Balance',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _balanceVisible
                                ? '${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}'
                                : '••••••',
                            style: AppTextStyles.displayLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (escrow > 0)
                            Row(
                              children: [
                                const Icon(Icons.lock_outline,
                                    size: 14, color: Colors.white60),
                                const SizedBox(width: 4),
                                Text(
                                  'In escrow: ${AppConstants.currencySymbol}${escrow.toStringAsFixed(2)}',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: Colors.white60),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _WalletAction(
                                  icon: Icons.add_circle_outline,
                                  label: 'Top Up',
                                  onTap: _showTopUp,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _WalletAction(
                                  icon: Icons.arrow_upward_outlined,
                                  label: 'Withdraw',
                                  onTap: _showWithdraw,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Stats row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _StatCard(
                            label: 'Total Earned',
                            value:
                                '${AppConstants.currencySymbol}${((_wallet?['total_earned'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            icon: Icons.trending_up,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: 'Total Spent',
                            value:
                                '${AppConstants.currencySymbol}${((_wallet?['total_spent'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            icon: Icons.trending_down,
                            color: AppColors.error,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Transactions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Transaction History',
                              style: AppTextStyles.headlineSmall),
                          Text(
                            '${_transactions.length} records',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Text('💳',
                                style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text('No transactions yet',
                                style: AppTextStyles.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              'Top up your wallet to get started.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) =>
                            _TransactionTile(txn: _transactions[i]),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WalletAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.labelLarge
                    .copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelSmall),
                  Text(value,
                      style: AppTextStyles.titleSmall
                          .copyWith(color: color, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> txn;
  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn['type'] == 'credit';
    final amount = (txn['amount_ghs'] as num).toDouble();
    final refType = txn['reference_type'] as String? ?? '';
    final status = txn['status'] as String? ?? 'completed';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForRef(refType),
              size: 18,
              color: isCredit ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labelForRef(refType),
                    style: AppTextStyles.titleSmall),
                Text(
                  txn['description'] as String? ??
                      _labelForRef(refType),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (status != 'completed')
                  Text(status.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                          color: status == 'pending'
                              ? AppColors.warning
                              : AppColors.error,
                          fontSize: 9)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
                style: AppTextStyles.titleSmall.copyWith(
                  color:
                      isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                timeago.format(
                    DateTime.parse(txn['created_at'] as String)),
                style:
                    AppTextStyles.labelSmall.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForRef(String ref) {
    if (ref.contains('topup')) return Icons.add_circle_outline;
    if (ref.contains('marketplace')) return Icons.storefront_outlined;
    if (ref.contains('consultation')) return Icons.support_agent_outlined;
    if (ref.contains('transport')) return Icons.local_shipping_outlined;
    if (ref.contains('course')) return Icons.menu_book_outlined;
    if (ref.contains('withdrawal')) return Icons.arrow_upward_outlined;
    if (ref.contains('fee')) return Icons.percent_outlined;
    return Icons.payment_outlined;
  }

  String _labelForRef(String ref) {
    if (ref.contains('topup')) return 'Wallet Top Up';
    if (ref.contains('marketplace_payment')) return 'Marketplace Purchase';
    if (ref.contains('escrow_release')) return 'Escrow Released';
    if (ref.contains('marketplace_refund')) return 'Marketplace Refund';
    if (ref.contains('consultation_payment')) return 'Consultation Fee';
    if (ref.contains('consultation_refund')) return 'Consultation Refund';
    if (ref.contains('transport_payment')) return 'Transport Payment';
    if (ref.contains('course_payment')) return 'Course Enrollment';
    if (ref.contains('withdrawal')) return 'Withdrawal';
    if (ref.contains('platform_fee')) return 'Platform Fee';
    return 'Transaction';
  }
}

// ── Top Up Sheet ────────────────────────────────────────────────────────────

class _TopUpSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _TopUpSheet({required this.onSuccess});

  @override
  ConsumerState<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<_TopUpSheet> {
  final _amountController = TextEditingController();
  String _method = 'momo';
  bool _isProcessing = false;

  static const _quickAmounts = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) return;

      if (_method == 'wallet') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot top up from wallet')));
        return;
      }

      final result = await PaymentService.chargeCard(
        context: context,
        email: user.email,
        amountGhs: amount,
        description: 'Wallet top-up',
      );

      if (result.success) {
        await PaymentService.topUpWallet(
          userId: user.id,
          amountGhs: amount,
          paystackRef: result.reference,
        );
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)} added to wallet!'),
            backgroundColor: AppColors.success,
          ));
        }
      }
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
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Top Up Wallet', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 20),

          // Quick amounts
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _quickAmounts.map((a) {
              return GestureDetector(
                onTap: () => setState(
                    () => _amountController.text = a.toStringAsFixed(0)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${AppConstants.currencySymbol}${a.toStringAsFixed(0)}',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₵)',
              prefixText: '₵ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Method
          Text('Pay via', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _MethodChip('momo', 'Mobile Money', _method,
                  (v) => setState(() => _method = v)),
              const SizedBox(width: 8),
              _MethodChip('card', 'Card', _method,
                  (v) => setState(() => _method = v)),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Proceed to Payment',
            isLoading: _isProcessing,
            onPressed: _topUp,
          ),
        ],
      ),
    );
  }
}

// ── Withdraw Sheet ──────────────────────────────────────────────────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  final double balance;
  final VoidCallback onSuccess;
  const _WithdrawSheet(
      {required this.balance, required this.onSuccess});

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amountController = TextEditingController();
  final _numberController = TextEditingController();
  String _network = 'MTN';
  bool _isProcessing = false;

  static const _networks = ['MTN', 'Vodafone', 'AirtelTigo'];

  @override
  void dispose() {
    _amountController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountController.text);
    final number = _numberController.text.trim();

    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (amount > widget.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance')));
      return;
    }
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your MoMo number')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) return;

      await PaymentService.withdrawFromWallet(
        userId: user.id,
        amountGhs: amount,
        momoNumber: number,
        momoNetwork: _network,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Withdrawal of ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)} initiated!'),
          backgroundColor: AppColors.success,
        ));
      }
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
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Withdraw to MoMo', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Available: ${AppConstants.currencySymbol}${widget.balance.toStringAsFixed(2)}',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₵)',
              prefixText: '₵ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // Network
          Text('Mobile Money Network', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: _networks.map((n) {
              final isSelected = _network == n;
              return GestureDetector(
                onTap: () => setState(() => _network = n),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primarySurface
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 1.5 : 1),
                  ),
                  child: Text(n,
                      style: AppTextStyles.labelMedium.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'MoMo Phone Number',
              hintText: '0241234567',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Withdraw',
            isLoading: _isProcessing,
            onPressed: _withdraw,
          ),
        ],
      ),
    );
  }
}

Widget _MethodChip(String value, String label, String selected,
    void Function(String) onTap) {
  final isSelected = selected == value;
  return GestureDetector(
    onTap: () => onTap(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySurface : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1),
      ),
      child: Text(label,
          style: AppTextStyles.labelMedium.copyWith(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary)),
    ),
  );
}
