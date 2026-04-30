import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/chat_repository.dart';

abstract class ChatState {}
class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}
class ChatLoaded extends ChatState {
  final List<Map<String, dynamic>> chats;
  ChatLoaded(this.chats);
}
class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _chatRepository;
  ChatCubit(this._chatRepository) : super(ChatInitial());

  void fetchChats() {
    emit(ChatLoading());
    _chatRepository.getChats().listen(
      (chats) => emit(ChatLoaded(chats)),
      onError: (e) => emit(ChatError(e.toString())),
    );
  }
}

abstract class MessageState {}
class MessageInitial extends MessageState {}
class MessageLoading extends MessageState {}
class MessageLoaded extends MessageState {
  final List<Map<String, dynamic>> messages;
  MessageLoaded(this.messages);
}
class MessageError extends MessageState {
  final String message;
  MessageError(this.message);
}

class MessageCubit extends Cubit<MessageState> {
  final ChatRepository _chatRepository;
  MessageCubit(this._chatRepository) : super(MessageInitial());

  void fetchMessages(String chatId) {
    emit(MessageLoading());
    _chatRepository.getMessages(chatId).listen(
      (messages) => emit(MessageLoaded(messages)),
      onError: (e) => emit(MessageError(e.toString())),
    );
  }

  Future<void> sendMessage(String chatId, String receiverId, String text) async {
    try {
      await _chatRepository.sendMessage(chatId, receiverId, text);
    } catch (e) {
      emit(MessageError(e.toString()));
    }
  }
}
