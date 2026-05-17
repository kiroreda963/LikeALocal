class ChatSettings {
  final bool allowMessages;
  final bool scheduleEnabled;
  final int scheduleStartHour;
  final int scheduleEndHour;

  const ChatSettings({
    this.allowMessages = true,
    this.scheduleEnabled = false,
    this.scheduleStartHour = 9,
    this.scheduleEndHour = 21,
  });

  factory ChatSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ChatSettings();
    return ChatSettings(
      allowMessages: map['allowMessages'] as bool? ?? true,
      scheduleEnabled: map['scheduleEnabled'] as bool? ?? false,
      scheduleStartHour: (map['scheduleStartHour'] as num?)?.toInt() ?? 9,
      scheduleEndHour: (map['scheduleEndHour'] as num?)?.toInt() ?? 21,
    );
  }

  Map<String, dynamic> toMap() => {
        'allowMessages': allowMessages,
        'scheduleEnabled': scheduleEnabled,
        'scheduleStartHour': scheduleStartHour,
        'scheduleEndHour': scheduleEndHour,
      };

  bool isAvailableNow([DateTime? when]) {
    if (!allowMessages) return false;
    if (!scheduleEnabled) return true;

    final hour = (when ?? DateTime.now()).hour;
    if (scheduleStartHour == scheduleEndHour) return true;

    if (scheduleStartHour < scheduleEndHour) {
      return hour >= scheduleStartHour && hour < scheduleEndHour;
    }
    return hour >= scheduleStartHour || hour < scheduleEndHour;
  }

  String scheduleLabel() {
    return '${_formatHour(scheduleStartHour)} – ${_formatHour(scheduleEndHour)}';
  }

  static String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$display $period';
  }
}
