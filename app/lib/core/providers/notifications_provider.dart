import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../state/session.dart';

class AppNotification {
  const AppNotification({required this.id, required this.type,
    required this.title, required this.body, required this.read,
    required this.createdAt});
  final int id;
  final String type, title, body;
  final bool read;
  final String createdAt;
}

class NotificationsState {
  const NotificationsState({this.items = const [], this.unreadCount = 0, this.loading = false});
  final List<AppNotification> items;
  final int unreadCount;
  final bool loading;
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._api) : super(const NotificationsState()) { load(); }
  final ApiClient _api;

  Future<void> load() async {
    state = NotificationsState(items: state.items, unreadCount: state.unreadCount, loading: true);
    try {
      final d = await _api.getJson('/notifications');
      final items = (d['notifications'] as List? ?? []).map((n) {
        final m = n as Map<String, dynamic>;
        return AppNotification(
          id: (m['id'] as num).toInt(),
          type: m['type'] as String? ?? '',
          title: m['title'] as String? ?? '',
          body: m['body'] as String? ?? '',
          read: m['read'] as bool? ?? false,
          createdAt: m['created_at'] as String? ?? '',
        );
      }).toList();
      state = NotificationsState(
        items: items,
        unreadCount: (d['unread_count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      state = const NotificationsState();
    }
  }

  Future<void> readAll() async {
    try {
      await _api.postJson('/notifications/read-all', {});
      final updated = state.items.map((n) => AppNotification(
        id: n.id, type: n.type, title: n.title, body: n.body,
        read: true, createdAt: n.createdAt,
      )).toList();
      state = NotificationsState(items: updated, unreadCount: 0);
    } catch (_) {}
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) {
    ref.watch(currentUserKeyProvider);
    return NotificationsNotifier(ref.watch(apiClientProvider));
  },
);
