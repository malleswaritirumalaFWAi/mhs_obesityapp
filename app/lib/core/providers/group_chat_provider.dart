import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class ChatMessage {
  const ChatMessage({required this.id, required this.text, required this.authorName,
    required this.isMe, required this.type, required this.createdAt, this.pinned = false});
  final int id;
  final String text, authorName, type, createdAt;
  final bool isMe, pinned;
}

class GroupChatState {
  const GroupChatState({this.messages = const [], this.loading = false, this.sending = false});
  final List<ChatMessage> messages;
  final bool loading, sending;
}

class GroupChatNotifier extends StateNotifier<GroupChatState> {
  GroupChatNotifier(this._api) : super(const GroupChatState()) { load(); }
  final ApiClient _api;

  Future<void> load() async {
    state = GroupChatState(messages: state.messages, loading: true);
    try {
      final d = await _api.getJson('/group/chat');
      final msgs = (d['messages'] as List? ?? []).map((m) {
        final mm = m as Map<String, dynamic>;
        return ChatMessage(
          id: (mm['id'] as num).toInt(),
          text: mm['text'] as String? ?? '',
          authorName: mm['author_name'] as String? ?? 'Member',
          isMe: mm['is_mine'] as bool? ?? false,
          type: mm['type'] as String? ?? 'user',
          createdAt: mm['created_at'] as String? ?? '',
          pinned: mm['pinned'] as bool? ?? false,
        );
      }).toList();
      state = GroupChatState(messages: msgs);
    } catch (_) { state = const GroupChatState(); }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    state = GroupChatState(messages: state.messages, sending: true);
    try {
      await _api.postJson('/group/chat', {'text': text});
      await load();
    } catch (_) {
      state = GroupChatState(messages: state.messages);
    }
  }
}

final groupChatProvider = StateNotifierProvider<GroupChatNotifier, GroupChatState>(
  (ref) {
    ref.watch(currentUserKeyProvider);
    return GroupChatNotifier(ref.watch(apiClientProvider));
  },
);
