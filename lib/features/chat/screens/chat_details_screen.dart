import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/chat_cubit.dart';
import '../data/chat_repository.dart';
import '../../listings/data/listing_repository.dart';
import '../../profile/data/rating_repository.dart';
import '../../profile/data/user_repository.dart';
import '../widgets/rate_user_dialog.dart';
import '../../../core/animations/app_animations.dart';
import '../../../core/widgets/user_title_badge.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../report/widgets/report_dialog.dart';

/// Navigation arguments for [ChatDetailsScreen].
///
/// The receiver's name and id come from whichever screen opened the chat, so
/// the header renders before the profile fetch resolves.
class ChatDetailsArgs {
  const ChatDetailsArgs({
    required this.chatId,
    required this.receiverName,
    required this.receiverId,
  });

  final String chatId;
  final String receiverName;
  final String receiverId;
}

class ChatDetailsScreen extends StatefulWidget {
  final String chatId;
  final String receiverName;
  final String receiverId;

  const ChatDetailsScreen({
    super.key,
    required this.chatId,
    required this.receiverName,
    required this.receiverId,
  });

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  AppUser? _receiverData;
  bool _hasRated = false;

  /// Id of the most recent inbound message this screen has cleared the badge
  /// for, so repeat snapshots don't each trigger a write.
  String? _lastReadMessageId;

  @override
  void initState() {
    super.initState();
    context.read<MessageCubit>().fetchMessages(widget.chatId);
    _markRead();
    _fetchReceiverData();
    _checkIfAlreadyRated();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchReceiverData() async {
    final userRepository = context.read<UserRepository>();
    try {
      final user = await userRepository.getUser(widget.receiverId);
      if (mounted) setState(() => _receiverData = user);
    } catch (_) {
      // A missing profile just leaves the header on its defaults.
    }
  }

  Future<void> _checkIfAlreadyRated() async {
    final ratingRepository = context.read<RatingRepository>();
    try {
      final hasRated = await ratingRepository.hasRated(
        chatId: widget.chatId,
        toId: widget.receiverId,
      );
      if (mounted) setState(() => _hasRated = hasRated);
    } catch (_) {
      // Leave the rate button enabled; the write is idempotent by id.
    }
  }

  /// Clears this chat's unread badge.
  ///
  /// Only fires when the newest inbound message is one we haven't already
  /// cleared for. Marking on every snapshot would put a write on the chat
  /// document each time anything in the conversation changed.
  void _markRead([List<Message>? messages]) {
    if (messages != null) {
      // Messages arrive newest-first.
      final newestInbound = messages
          .where((m) => !m.isFrom(_currentUserId))
          .firstOrNull;
      if (newestInbound == null) return;
      if (newestInbound.id == _lastReadMessageId) return;
      _lastReadMessageId = newestInbound.id;
    }

    context.read<ChatRepository>().markAsRead(widget.chatId);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    context.read<MessageCubit>().sendMessage(
      widget.chatId,
      widget.receiverId,
      _messageController.text.trim(),
    );
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.solidBlack,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.borderGrey,
              child: Icon(Icons.person, size: 16, color: AppColors.textGrey),
            ),
            AppSizes.gapWSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName, style: AppTextStyles.bodyMediumDark),
                Row(
                  children: [
                    Icon(Icons.star, size: 10, color: AppColors.primaryYellow),
                    const SizedBox(width: 2),
                    Text(
                      (_receiverData ?? AppUser.empty).formattedRating,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    UserTitleBadge(
                      title: (_receiverData ?? AppUser.empty).title,
                      isCompact: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.solidBlack),
            onSelected: (value) {
              if (value == 'report') {
                ReportDialog.show(
                  context,
                  targetId: widget.receiverId,
                  targetType: ReportTargetType.user,
                  targetName: widget.receiverName,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Report User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<MessageCubit, MessageState>(
              listener: (context, state) {
                if (state is MessageLoaded) _markRead(state.messages);
              },
              builder: (context, state) {
                if (state is MessageLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is MessageError) {
                  return ErrorStateView(
                    error: state.message,
                    onRetry: () => context.read<MessageCubit>().fetchMessages(
                      widget.chatId,
                    ),
                  );
                }
                if (state is MessageLoaded) {
                  final messages = state.messages;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.isFrom(_currentUserId);

                      return SlideIn(
                        fromLeft: !isMe,
                        child: msg.isDeal
                            ? _buildDealCard(msg, isMe)
                            : _buildMessageBubble(msg, isMe),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Future<void> _updateDeal(
    String messageId,
    DealStatus status,
    DealRequest deal,
  ) async {
    final chatRepo = context.read<ChatRepository>();
    final listingRepo = context.read<ListingRepository>();

    // The client only moves the deal's status. Everything that follows from
    // completion — both parties' deal counts, their titles, marking the
    // listing sold — is settled by onDealCompleted, because none of it is
    // safe to let a device decide.
    await chatRepo.updateDealStatus(widget.chatId, messageId, status);

    if (status == DealStatus.completed) {
      if (mounted) _showRatingDialog();
      return;
    }

    if (deal.itemId.isEmpty) return;
    switch (status) {
      case DealStatus.accepted:
        await listingRepo.updateListingStatus(
          deal.itemId,
          ListingStatus.reserved,
        );
      case DealStatus.declined:
        await listingRepo.updateListingStatus(
          deal.itemId,
          ListingStatus.active,
        );
      case DealStatus.pending:
      case DealStatus.completed:
        break;
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => RateUserDialog(
        userName: widget.receiverName,
        onSubmitted: (rating, comment) {
          context.read<MessageCubit>().submitRating(
            toId: widget.receiverId,
            rating: rating,
            comment: comment,
            chatId: widget.chatId,
          );

          // Mark as rated immediately so the button updates
          if (mounted) setState(() => _hasRated = true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your feedback!')),
          );
        },
      ),
    );
  }

  Widget _buildDealCard(Message msg, bool isMe) {
    final deal = msg.deal!;
    final status = deal.status;
    final messageId = msg.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.solidBlack, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                deal.isFromAuction ? Icons.gavel_rounded : Icons.handshake,
                color: deal.isFromAuction
                    ? AppColors.solidBlack
                    : AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // A price the room decided is not a price either of them
                  // proposed, and the card should not pretend otherwise.
                  deal.isFromAuction ? 'WON AT AUCTION' : 'DEAL REQUEST',
                  style: AppTextStyles.heading2.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          if (deal.isFromAuction)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Agreed at the winning bid. Meet up, then ${isMe ? 'mark it' : 'they will mark it'} complete.',
                style: AppTextStyles.bodySmall.copyWith(height: 1.4),
              ),
            ),
          const Divider(height: 24),
          Text(
            deal.title,
            style: AppTextStyles.bodyMediumDark.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Price: ${deal.formattedPrice}',
            style: AppTextStyles.bodyMediumDark,
          ),
          const SizedBox(height: 16),

          if (status == DealStatus.pending) ...[
            if (isMe)
              const Center(
                child: Text(
                  'Waiting for seller response...',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateDeal(
                        messageId,
                        DealStatus.declined,
                        deal,
                      ),
                      child: const Text('DECLINE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _updateDeal(
                        messageId,
                        DealStatus.accepted,
                        deal,
                      ),
                      child: const Text('ACCEPT'),
                    ),
                  ),
                ],
              ),
          ] else if (status == DealStatus.accepted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '🤝 DEAL ACCEPTED - ITEM RESERVED',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Only show completion button to the Seller
            if (deal.isSeller(_currentUserId))
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                      color: AppColors.solidBlack,
                      width: 2,
                    ),
                  ),
                ),
                onPressed: () => _updateDeal(
                  messageId,
                  DealStatus.completed,
                  deal,
                ),
                child: const Text('MARK AS COMPLETED'),
              )
            else
              const Center(
                child: Text(
                  'Waiting for seller to confirm handover...',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
          ] else if (status == DealStatus.completed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '✅ DEAL COMPLETED',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _hasRated ? null : _showRatingDialog,
              style: _hasRated
                  ? OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_hasRated) ...const [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 6),
                  ],
                  Text(_hasRated ? 'RATED' : 'RATE USER'),
                ],
              ),
            ),
          ] else if (status == DealStatus.declined) ...[
            const Center(
              child: Text(
                '❌ Deal Declined',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    final sentAt = msg.sentAt;
    final time = sentAt == null ? '' : DateFormat('HH:mm').format(sentAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryBlue : AppColors.white,
          border: Border.all(color: AppColors.solidBlack, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.solidBlack.withValues(alpha: 0.1),
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isMe ? AppColors.white : AppColors.solidBlack,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 8,
                color: (isMe ? AppColors.white : AppColors.textGrey).withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
          top: BorderSide(color: AppColors.solidBlack, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.solidBlack, width: 1.5),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                decoration: AppTheme.bareInput(
                  hintText: 'Type a message...',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ScaleAnimation(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.solidBlack, offset: Offset(2, 2)),
                ],
              ),
              child: const Icon(Icons.send, color: AppColors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
