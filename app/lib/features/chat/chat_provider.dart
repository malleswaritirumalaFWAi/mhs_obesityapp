import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/session.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromCoach,
    this.card = false,
  });

  final String text;
  final bool fromCoach;
  final bool card;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String? ?? '',
        fromCoach: j['from_coach'] as bool? ?? false,
      );
}

class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() {
    ref.watch(currentUserKeyProvider);
    return _fetch();
  }

  Future<List<ChatMessage>> _fetch() async {
    try {
      final json = await ref.read(apiClientProvider).getJson('/chat');
      final messages = json['messages'] as List? ?? [];
      return messages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      if (AppConfig.demoMode) return _demoMessages();
      return [];
    }
  }

  Future<void> sendMessage(String text) async {
    // If state is error (e.g. no backend), seed with empty list so messages show.
    if (state is AsyncError) {
      state = AsyncData(_demoMessages());
    }
    // Optimistically add user message immediately.
    state = state.whenData((msgs) => [...msgs, ChatMessage(text: text, fromCoach: false)]);
    try {
      final json = await ref.read(apiClientProvider).postJson('/chat', {'text': text});
      final reply = json['reply'] as String? ?? '';
      if (reply.isNotEmpty) {
        state = state.whenData((msgs) => [...msgs, ChatMessage(text: reply, fromCoach: true)]);
      }
    } catch (_) {
      // Backend unavailable — add a friendly fallback coach reply.
      if (AppConfig.demoMode) {
        const fallback = 'Great work staying consistent! Keep it up and hydrate well today 💪';
        state = state.whenData((msgs) => [...msgs, const ChatMessage(text: fallback, fromCoach: true)]);
      }
    }
  }

  static List<ChatMessage> _demoMessages() => const [
        ChatMessage(text: "Hi! I'm Coach Priya. Welcome to FitQuest 🎉 How are you feeling today?", fromCoach: true),
      ];
}

final chatProvider =
    AsyncNotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);
