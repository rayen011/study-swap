import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/chat_summary.dart';
import '../../../core/models/message.dart';
import '../../profile/data/rating_repository.dart';
import '../data/chat_repository.dart';

// ── Conversation list ────────────────────────────────────────────────────────

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatSummary> chats;
  const ChatLoaded(this.chats);

  @override
  List<Object?> get props => [chats];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _chatRepository;
  StreamSubscription<List<ChatSummary>>? _subscription;

  ChatCubit(this._chatRepository) : super(ChatInitial());

  void fetchChats() {
    emit(ChatLoading());
    _subscription?.cancel();
    _subscription = _chatRepository.getChats().listen((chats) {
      // Newest conversation first. Sorted here rather than in the query so
      // the chats collection needs no composite index.
      final sorted = [...chats]..sort((a, b) {
        final aTime = a.lastMessageAt;
        final bTime = b.lastMessageAt;
        if (aTime == null) return bTime == null ? 0 : -1;
        if (bTime == null) return 1;
        return bTime.compareTo(aTime);
      });
      emit(ChatLoaded(sorted));
    }, onError: (Object e) => emit(ChatError(e.toString())));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

// ── Messages within one conversation ─────────────────────────────────────────

abstract class MessageState extends Equatable {
  const MessageState();

  @override
  List<Object?> get props => [];
}

class MessageInitial extends MessageState {}

class MessageLoading extends MessageState {}

class MessageLoaded extends MessageState {
  final List<Message> messages;
  const MessageLoaded(this.messages);

  @override
  List<Object?> get props => [messages];
}

class MessageError extends MessageState {
  final String message;
  const MessageError(this.message);

  @override
  List<Object?> get props => [message];
}

class MessageCubit extends Cubit<MessageState> {
  final ChatRepository _chatRepository;
  final RatingRepository _ratingRepository;
  StreamSubscription<List<Message>>? _subscription;

  MessageCubit(this._chatRepository, this._ratingRepository)
    : super(MessageInitial());

  /// Subscribes to one conversation, replacing any previous subscription.
  ///
  /// Cancelling first matters: this cubit is provided app-wide, so without it
  /// every chat opened during a session keeps emitting and the conversations
  /// overwrite each other.
  void fetchMessages(String chatId) {
    emit(MessageLoading());
    _subscription?.cancel();
    _subscription = _chatRepository
        .getMessages(chatId)
        .listen(
          (messages) => emit(MessageLoaded(messages)),
          onError: (Object e) => emit(MessageError(e.toString())),
        );
  }

  Future<void> sendMessage(
    String chatId,
    String receiverId,
    String text,
  ) async {
    try {
      await _chatRepository.sendMessage(chatId, receiverId, text);
    } catch (e) {
      emit(MessageError(e.toString()));
    }
  }

  Future<void> completeDeal({
    required String chatId,
    required String messageId,
    required String itemId,
    required String buyerId,
    required String sellerId,
  }) async {
    try {
      await _ratingRepository.completeDeal(
        chatId: chatId,
        messageId: messageId,
        itemId: itemId,
        buyerId: buyerId,
        sellerId: sellerId,
      );
    } catch (e) {
      emit(MessageError(e.toString()));
    }
  }

  Future<void> submitRating({
    required String toId,
    required double rating,
    String? comment,
    required String chatId,
  }) async {
    try {
      await _ratingRepository.submitRating(
        toId: toId,
        rating: rating,
        comment: comment,
        chatId: chatId,
      );
    } catch (e) {
      emit(MessageError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
