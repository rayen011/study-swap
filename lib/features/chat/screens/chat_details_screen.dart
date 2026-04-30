import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../logic/chat_cubit.dart';
import '../data/chat_repository.dart';
import '../../listings/data/listing_repository.dart';
import '../../../core/widgets/rating_dialog.dart';
import '../../../core/animations/app_animations.dart';

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

  @override
  void initState() {
    super.initState();
    context.read<MessageCubit>().fetchMessages(widget.chatId);
    _markRead();
  }

  void _markRead() {
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
                Text(
                  'Online',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 10,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<MessageCubit, MessageState>(
              listener: (context, state) {
                if (state is MessageLoaded) {
                  _markRead();
                }
              },
              builder: (context, state) {
                if (state is MessageLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is MessageError) {
                  return Center(child: Text(state.message));
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
                      final isMe = msg['senderId'] == _currentUserId;
                      
                      if (msg['type'] == 'deal') {
                        return SlideIn(
                          fromLeft: !isMe,
                          child: _buildDealCard(msg, isMe),
                        );
                      }
                      
                      return SlideIn(
                        fromLeft: !isMe,
                        child: _buildMessageBubble(
                          msg['text'],
                          isMe,
                          msg['timestamp'],
                        ),
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

  Future<void> _updateDeal(String messageId, String status, {String? listingId}) async {
    final chatRepo = context.read<ChatRepository>();
    final listingRepo = context.read<ListingRepository>();
    
    await chatRepo.updateDealStatus(widget.chatId, messageId, status);
    
    if (listingId != null) {
      if (status == 'accepted') {
        await listingRepo.updateListingStatus(listingId, 'reserved');
      } else if (status == 'completed') {
        await listingRepo.updateListingStatus(listingId, 'sold');
        _showRatingDialog(listingId);
      } else if (status == 'declined') {
        await listingRepo.updateListingStatus(listingId, 'active');
      }
    }
  }

  void _showRatingDialog(String listingId) {
    showDialog(
      context: context,
      builder: (ctx) => RatingDialog(
        title: 'Listing #$listingId',
        onSubmitted: (rating, comment) async {
          // Save rating to Firestore
          await FirebaseFirestore.instance.collection('ratings').add({
            'listingId': listingId,
            'fromId': _currentUserId,
            'toId': widget.receiverId,
            'rating': rating,
            'comment': comment,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thank you for your feedback!')),
            );
          }
        },
      ),
    );
  }

  Widget _buildDealCard(Map<String, dynamic> msg, bool isMe) {
    final dealData = msg['dealData'] as Map<String, dynamic>;
    final status = dealData['status'] ?? 'pending';
    final itemId = dealData['itemId'];
    final title = dealData['title'];
    final price = dealData['price'];
    final messageId = msg['id'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.solidBlack, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text('DEAL REQUEST', style: AppTextStyles.heading2.copyWith(fontSize: 16)),
            ],
          ),
          const Divider(height: 24),
          Text(title, style: AppTextStyles.bodyMediumDark.copyWith(fontWeight: FontWeight.bold)),
          Text('Price: £$price', style: AppTextStyles.bodyMediumDark),
          const SizedBox(height: 16),
          
          if (status == 'pending') ...[
            if (isMe)
              const Center(child: Text('Waiting for seller response...', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateDeal(messageId, 'declined'),
                      child: const Text('DECLINE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => _updateDeal(messageId, 'accepted', listingId: itemId),
                      child: const Text('ACCEPT'),
                    ),
                  ),
                ],
              ),
          ] else if (status == 'accepted') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('🤝 DEAL ACCEPTED - ITEM RESERVED', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
            if (isMe) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40)),
                onPressed: () => _updateDeal(messageId, 'completed', listingId: itemId),
                child: const Text('MARK AS BOUGHT'),
              ),
            ]
          ] else if (status == 'completed') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('✅ ITEM SOLD & BOUGHT', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          ] else if (status == 'declined') ...[
            const Center(child: Text('❌ Deal Declined', style: TextStyle(color: Colors.red, fontSize: 12))),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, dynamic timestamp) {
    String time = '';
    if (timestamp != null && timestamp is DateTime) {
      time = DateFormat('HH:mm').format(timestamp);
    } else if (timestamp != null) {
      // Handle Firestore Timestamp
      try {
        time = DateFormat('HH:mm').format(timestamp.toDate());
      } catch (_) {}
    }

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
              color: AppColors.solidBlack.withOpacity(0.1),
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
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isMe ? AppColors.white : AppColors.solidBlack,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 8,
                color: (isMe ? AppColors.white : AppColors.textGrey)
                    .withOpacity(0.7),
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
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
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
