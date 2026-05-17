import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Models/chat_settings_model.dart';
import '../../services/chat_settings_service.dart';

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  final ChatSettingsService _service = ChatSettingsService();

  bool _loading = true;
  bool _saving = false;
  bool _allowMessages = true;
  bool _scheduleEnabled = false;
  int _startHour = 9;
  int _endHour = 21;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final settings = await _service.getSettings(user.uid);
    if (!mounted) return;
    setState(() {
      _allowMessages = settings.allowMessages;
      _scheduleEnabled = settings.scheduleEnabled;
      _startHour = settings.scheduleStartHour;
      _endHour = settings.scheduleEndHour;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      await _service.saveSettings(
        user.uid,
        ChatSettings(
          allowMessages: _allowMessages,
          scheduleEnabled: _scheduleEnabled,
          scheduleStartHour: _startHour,
          scheduleEndHour: _endHour,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickHour({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isStart ? _startHour : _endHour, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startHour = picked.hour;
      } else {
        _endHour = picked.hour;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        title: const Text(
          'Chat & Privacy',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionCard(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Allow messages',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'When off, other users cannot start a chat with you.',
                      ),
                      value: _allowMessages,
                      activeColor: const Color(0xFF143C23),
                      onChanged: (value) => setState(() => _allowMessages = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Chat schedule',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Only receive new chats during the hours you choose.',
                      ),
                      value: _scheduleEnabled,
                      activeColor: const Color(0xFF143C23),
                      onChanged: _allowMessages
                          ? (value) => setState(() => _scheduleEnabled = value)
                          : null,
                    ),
                    if (_scheduleEnabled && _allowMessages) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        title: const Text('Available from'),
                        trailing: Text(
                          TimeOfDay(hour: _startHour, minute: 0).format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _pickHour(isStart: true),
                      ),
                      ListTile(
                        title: const Text('Available until'),
                        trailing: Text(
                          TimeOfDay(hour: _endHour, minute: 0).format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _pickHour(isStart: false),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save settings'),
                ),
              ],
            ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
