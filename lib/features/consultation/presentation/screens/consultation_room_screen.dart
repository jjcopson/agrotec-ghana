import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../shared/models/consultation_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_avatar.dart';

class ConsultationRoomScreen extends ConsumerStatefulWidget {
  final String consultationId;
  const ConsultationRoomScreen({super.key, required this.consultationId});

  @override
  ConsumerState<ConsultationRoomScreen> createState() =>
      _ConsultationRoomScreenState();
}

class _ConsultationRoomScreenState
    extends ConsumerState<ConsultationRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  ConsultationModel? _consultation;
  List<ConsultationMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showPaymentBanner = false;
  Timer? _freeTimer;
  int _freeSecondsLeft = 600; // 10 minutes
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadConsultation();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _freeTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadConsultation() async {
    try {
      final data = await SupabaseService.client
          .from('consultations')
          .select('*, expert_profiles(*)')
          .eq('id', widget.consultationId)
          .single();

      final msgData = await SupabaseService.client
          .from('consultation_messages')
          .select('*, users(full_name, avatar_url)')
          .eq('consultation_id', widget.consultationId)
          .order('created_at', ascending: true);

      setState(() {
        _consultation = ConsultationModel.fromJson(data);
        _messages = (msgData as List)
            .map((m) => ConsultationMessageModel.fromJson(m))
            .toList();
        _isLoading = false;
        _showPaymentBanner = _consultation!.needsPayment;
      });

      // Start free timer if session is active and not yet hit threshold
      if (!_consultation!.isFreeThresholdHit &&
          _consultation!.freeStartAt != null) {
        _startFreeTimer();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startFreeTimer() {
    final startAt = _consultation!.freeStartAt!;
    _freeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startAt).inSeconds;
      final remaining = 600 - elapsed;

      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _freeSecondsLeft = 0;
          _showPaymentBanner = _consultation!.sessionPriceGhs > 0;
        });
        _refreshConsultation();
      } else {
        setState(() => _freeSecondsLeft = remaining);
      }
    });
  }

  Future<void> _refreshConsultation() async {
    final data = await SupabaseService.client
        .from('consultations')
        .select('*, expert_profiles(*)')
        .eq('id', widget.consultationId)
        .single();
    setState(() {
      _consultation = ConsultationModel.fromJson(data);
      _showPaymentBanner = _consultation!.needsPayment;
    });
  }

  void _subscribeToMessages() {
    _channel = SupabaseService.channel('consultation:${widget.consultationId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'consultation_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'consultation_id',
          value: widget.consultationId,
        ),
        callback: (payload) {
          final newMsg = ConsultationMessageModel.fromJson(
              payload.newRecord as Map<String, dynamic>);
          setState(() => _messages.add(newMsg));
          _scrollToBottom();
        },
      )
      ..subscribe();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    if (_consultation == null) return;

    // Check if payment required
    if (_consultation!.needsPayment) {
      setState(() => _showPaymentBanner = true);
      return;
    }

    setState(() => _isSending = true);
    try {
      await SupabaseService.client.from('consultation_messages').insert({
        'consultation_id': widget.consultationId,
        'sender_id': SupabaseService.currentUserId!,
        'content': content,
        'message_type': 'text',
      });
      _messageController.clear();
      _scrollToBottom();
      await _refreshConsultation();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _payForSession(BuildContext context) async {
    if (_consultation == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(consultation: _consultation!),
    );
    if (result == true) {
      await _refreshConsultation();
      setState(() => _showPaymentBanner = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final consultation = _consultation!;
    final currentUserId = SupabaseService.currentUserId;
    final isClient = currentUserId == consultation.clientId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            AppAvatar(
              imageUrl: isClient
                  ? consultation.expertAvatar
                  : consultation.clientAvatar,
              name: isClient
                  ? consultation.expertName
                  : consultation.clientName,
              size: 36,
              showVerified: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClient
                        ? consultation.expertName ?? 'Expert'
                        : consultation.clientName ?? 'Client',
                    style: AppTextStyles.titleSmall,
                  ),
                  Text(
                    consultation.expertLabel?.toUpperCase() ?? 'EXPERT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showConsultationInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Free threshold banner
          if (!consultation.isFreeThresholdHit)
            _FreeThresholdBanner(
              secondsLeft: _freeSecondsLeft,
              messagesLeft: consultation.messagesRemaining,
            ),

          // Payment required banner
          if (_showPaymentBanner && consultation.sessionPriceGhs > 0)
            _PaymentRequiredBanner(
              price: consultation.sessionPriceGhs,
              onPay: () => _payForSession(context),
            ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(topic: consultation.topic)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg.senderId == currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isMine: isMine,
                      );
                    },
                  ),
          ),

          // Input bar
          _MessageInput(
            controller: _messageController,
            isSending: _isSending,
            isBlocked: _showPaymentBanner && consultation.sessionPriceGhs > 0,
            onSend: _sendMessage,
            onPayTap: () => _payForSession(context),
          ),
        ],
      ),
    );
  }

  void _showConsultationInfo(BuildContext context) {
    final c = _consultation!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultation Details', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 16),
            _InfoRow('Topic', c.topic),
            _InfoRow('Session Price', c.sessionPriceGhs == 0
                ? 'Free'
                : '₵${c.sessionPriceGhs.toStringAsFixed(2)}'),
            _InfoRow('Payment Status', c.paymentStatus.toUpperCase()),
            _InfoRow('Status', c.status.replaceAll('_', ' ').toUpperCase()),
            _InfoRow('Messages', '${c.messageCount}'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary)),
          ),
          Text(value, style: AppTextStyles.titleSmall),
        ],
      ),
    );
  }
}

class _FreeThresholdBanner extends StatelessWidget {
  final int secondsLeft;
  final int messagesLeft;

  const _FreeThresholdBanner({
    required this.secondsLeft,
    required this.messagesLeft,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.success.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text(
            'Free: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} • $messagesLeft msg left',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

class _PaymentRequiredBanner extends StatelessWidget {
  final double price;
  final VoidCallback onPay;

  const _PaymentRequiredBanner({required this.price, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withOpacity(0.12),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free session ended. Pay ₵${price.toStringAsFixed(2)} to continue.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: onPay,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ConsultationMessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            AppAvatar(
              imageUrl: message.senderAvatar,
              name: message.senderName,
              size: 28,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    border: isMine
                        ? null
                        : Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isMine ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!message.isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Paid',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.warning,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    if (!message.isFree) const SizedBox(width: 4),
                    Text(
                      _formatTime(message.createdAt),
                      style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isBlocked;
  final VoidCallback onSend;
  final VoidCallback onPayTap;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.isBlocked,
    required this.onSend,
    required this.onPayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isBlocked,
              decoration: InputDecoration(
                hintText: isBlocked
                    ? 'Pay to continue chatting...'
                    : 'Type a message...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => isBlocked ? onPayTap() : onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isBlocked ? onPayTap : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isBlocked ? AppColors.warning : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      isBlocked ? Icons.lock_open : Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String topic;
  const _EmptyChat({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Consultation Started',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Topic: $topic\n\nSend your first message to begin. The first 10 minutes or 10 messages are free.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final ConsultationModel consultation;
  const _PaymentSheet({required this.consultation});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  String _paymentMethod = 'wallet';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Pay for Session', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Continue your consultation with ${c.expertName ?? 'the expert'}',
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Price breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _PriceRow('Session fee',
                    '₵${c.sessionPriceGhs.toStringAsFixed(2)}'),
                _PriceRow('Platform fee (5%)',
                    '₵${c.platformFeeGhs.toStringAsFixed(2)}'),
                const Divider(height: 16),
                _PriceRow(
                  'Total',
                  '₵${c.sessionPriceGhs.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Payment Method', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          _PayMethodOption(
            value: 'wallet',
            label: 'Wallet',
            icon: Icons.account_balance_wallet_outlined,
            selected: _paymentMethod == 'wallet',
            onTap: () => setState(() => _paymentMethod = 'wallet'),
          ),
          const SizedBox(height: 8),
          _PayMethodOption(
            value: 'momo',
            label: 'Mobile Money',
            icon: Icons.phone_android_outlined,
            selected: _paymentMethod == 'momo',
            onTap: () => setState(() => _paymentMethod = 'momo'),
          ),
          const SizedBox(height: 24),

          AppButton(
            label: 'Pay ₵${c.sessionPriceGhs.toStringAsFixed(2)}',
            isLoading: _isProcessing,
            onPressed: _processPayment,
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    try {
      await PaymentService.payConsultation(
        consultationId: widget.consultation.id,
        clientId: widget.consultation.clientId,
        expertId: widget.consultation.expertId,
        sessionPriceGhs: widget.consultation.sessionPriceGhs,
        paymentMethod: _paymentMethod,
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
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.titleSmall
                  : AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary)),
          Text(value,
              style: bold
                  ? AppTextStyles.titleSmall.copyWith(color: AppColors.primary)
                  : AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _PayMethodOption extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.titleSmall),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
