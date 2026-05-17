import 'package:cloud_firestore/cloud_firestore.dart';

import '../Models/chat_settings_model.dart';

class ChatSettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ChatSettings> getSettings(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return const ChatSettings();
    return ChatSettings.fromMap(
      data['chatSettings'] as Map<String, dynamic>?,
    );
  }

  Future<void> saveSettings(String userId, ChatSettings settings) async {
    await _db.collection('users').doc(userId).set(
      {'chatSettings': settings.toMap()},
      SetOptions(merge: true),
    );
  }

  /// Returns a user-facing reason when messaging is blocked, or null if allowed.
  Future<String?> getMessagingBlockReason(String targetUserId) async {
    final settings = await getSettings(targetUserId);

    if (!settings.allowMessages) {
      return 'This user is not accepting new messages.';
    }

    if (!settings.isAvailableNow()) {
      return 'This user is only available to chat during '
          '${settings.scheduleLabel()}.';
    }

    return null;
  }
}
