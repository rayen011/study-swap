import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/models/chat_summary.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/error_state_view.dart';
import '../logic/chat_cubit.dart';
import 'chat_details_screen.dart';

/// ChatScreen: Displays the list of active conversations.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    context.read<ChatCubit>().fetchChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'MESSAGES',
          style: AppTextStyles.heading2.copyWith(fontSize: 20),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.solidBlack, height: 2),
        ),
      ),
      body: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ChatError) {
            return ErrorStateView(
              error: state.message,
              icon: Icons.chat_bubble_outline,
              onRetry: () => context.read<ChatCubit>().fetchChats(),
            );
          }
          if (state is ChatLoaded) {
            if (state.chats.isEmpty) {
              return _buildEmptyState();
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.chats.length,
              itemBuilder: (context, index) {
                final chat = state.chats[index];
                return _buildChatTile(chat);
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildChatTile(ChatSummary chat) {
    final otherUserId = chat.otherParticipantId(_currentUserId);
    final otherUserName = chat.otherParticipantName(_currentUserId);
    final lastMessage = chat.hasMessages ? chat.lastMessage : 'No messages yet';
    final sentAt = chat.lastMessageAt;
    final timeStr = sentAt == null ? '' : DateFormat('HH:mm').format(sentAt);

    return GestureDetector(
      onTap: () => context.push(
        '/chat-details',
        extra: ChatDetailsArgs(
          chatId: chat.id,
          receiverName: otherUserName,
          receiverId: otherUserId,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.solidBlack, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.solidBlack, width: 1.5),
              ),
              child: const Icon(Icons.person, color: AppColors.textGrey),
            ),
            AppSizes.gapWSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        otherUserName,
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textGrey.withValues(alpha: 0.5),
          ),
          AppSizes.gapHMD,
          Text('No conversations yet', style: AppTextStyles.bodyMediumDark),
          Text(
            'Message a seller to start chatting!',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
